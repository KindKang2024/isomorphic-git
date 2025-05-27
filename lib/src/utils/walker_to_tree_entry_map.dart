import 'dart:async';

import 'package:async/async.dart'; // For AsyncLock
import '../commands/stage.dart';
import '../commands/tree.dart';
import '../commands/workdir.dart';
import '../commands/walk.dart';
import '../commands/write_tree.dart';
import '../errors/internal_error.dart';
import '../errors/not_found_error.dart';
import '../managers/git_ignore_manager.dart';
import '../managers/git_index_manager.dart';
import '../storage/read_object.dart';
import '../storage/read_object_loose.dart';
import '../storage/object_storage.dart'; // For writeObject
import '../utils/join.dart';
import '../utils/posixify_path_buffer.dart';
import '../models/fs.dart';
import '../models/walker_entry.dart';
import '../models/tree_entry.dart';
import '../models/stat.dart';

final _treeMap = {'stage': STAGE, 'workdir': WORKDIR};

AsyncLock? _lock;
Future<T> acquireLock<T>(String ref, Future<T> Function() callback) {
  _lock ??= AsyncLock();
  return _lock!.synchronized(callback, timeout: Duration(seconds: 60));
}

Future<String?> _checkAndWriteBlob(
  FS fs,
  String gitdir,
  String dir,
  String filepath,
  String? oid,
) async {
  final currentFilepath = join(dir, filepath);
  Stat? stats;
  try {
    stats = await fs.lstat(currentFilepath);
  } catch (e) {
    throw NotFoundError(currentFilepath);
  }
  if (stats == null) throw NotFoundError(currentFilepath);
  if (stats.isDirectory) {
    throw InternalError('$currentFilepath: file expected, but found directory');
  }

  ReadObjectLooseResult? objResult;
  if (oid != null) {
    try {
      objResult = await readObjectLoose(fs: fs, gitdir: gitdir, oid: oid);
    } catch (e) {
      // If object not found, we'll write it
    }
  }

  String? retOid = objResult?.oid;

  if (retOid == null) {
    await acquireLock(currentFilepath, () async {
      // Re-check if oid was written by another process while waiting for lock
      if (oid != null) {
        try {
          final tempObj = await readObjectLoose(
            fs: fs,
            gitdir: gitdir,
            oid: oid,
          );
          if (tempObj.oid != null) {
            retOid = tempObj.oid;
            return;
          }
        } catch (e) {
          // continue to write
        }
      }

      final object = stats.isSymbolicLink
          ? posixifyPathBuffer(await fs.readlink(currentFilepath))
          : await fs.read(currentFilepath);

      if (object == null) throw NotFoundError(currentFilepath);

      retOid = await writeObject(
        fs: fs,
        gitdir: gitdir,
        type: 'blob',
        object: object,
      );
    });
  }
  return retOid;
}

class _ProcessedEntry extends TreeEntry {
  List<TreeEntry>? children;
  _ProcessedEntry({
    required String mode,
    required String path,
    required String oid,
    required String type,
    this.children,
  }) : super(mode: mode, path: path, oid: oid, type: type);
}

Future<List<_ProcessedEntry>> _processTreeEntries({
  required FS fs,
  required String dir,
  required String gitdir,
  required List<_ProcessedEntry> entries,
}) async {
  Future<_ProcessedEntry> processTreeEntry(_ProcessedEntry entry) async {
    if (entry.type == 'tree') {
      if (entry.oid == null || entry.oid.isEmpty) {
        final children = await Future.wait(
          entry.children!.map(processTreeEntry),
        );
        entry.oid = await writeTree(fs: fs, gitdir: gitdir, tree: children);
        entry.mode = '040000'; // directory
      }
    } else if (entry.type == 'blob') {
      entry.oid = (await _checkAndWriteBlob(
        fs,
        gitdir,
        dir,
        entry.path,
        entry.oid,
      ))!;
      entry.mode = '100644'; // file
    }
    entry.path = entry.path.split('/').last;
    return entry;
  }

  return Future.wait(entries.map(processTreeEntry));
}

Future<String?> writeTreeChanges({
  required FS fs,
  required String dir,
  required String gitdir,
  required List<dynamic> treePair, // [TREE(ref: 'HEAD'), 'STAGE']
}) async {
  final isStage = treePair[1] == 'stage';
  final trees = treePair
      .map((t) => t is String ? _treeMap[t]!() : t as Walker)
      .toList();

  final changedEntries = <List<WalkerEntry?>>[];

  Future<_ProcessedEntry?> map(
    String filepath,
    List<WalkerEntry?> entries,
  ) async {
    final head = entries[0];
    final stage = entries[1];

    if (filepath == '.' ||
        (await GitIgnoreManager.isIgnored(
          fs: fs,
          dir: dir,
          gitdir: gitdir,
          filepath: filepath,
        ))) {
      return null;
    }

    if (stage != null) {
      if (head == null ||
          ((await head.oid()) != (await stage.oid()) &&
              (await stage.oid()) != null)) {
        changedEntries.add([head, stage]);
      }
      return _ProcessedEntry(
        mode: await stage.mode(),
        path: filepath,
        oid: (await stage.oid()) ?? '',
        type: await stage.type(),
      );
    }
    return null;
  }

  Future<_ProcessedEntry?> reduce(
    _ProcessedEntry? parent,
    List<_ProcessedEntry?> children,
  ) async {
    final filteredChildren = children
        .where((c) => c != null)
        .cast<_ProcessedEntry>()
        .toList();
    if (parent == null) {
      return filteredChildren.isNotEmpty
          ? _ProcessedEntry(
              mode: '',
              path: '.',
              oid: '',
              type: 'tree',
              children: filteredChildren,
            )
          : null;
    } else {
      parent.children = filteredChildren;
      return parent;
    }
  }

  Future<List<List<WalkerEntry?>>> iterate(
    Future<dynamic> Function(List<WalkerEntry?>) walkFn,
    List<List<WalkerEntry?>> children,
  ) async {
    final filtered = <List<WalkerEntry?>>[];
    for (final child in children) {
      final head = child[0];
      final stage = child[1];
      if (isStage) {
        if (stage != null) {
          if (await fs.exists(join(dir, stage.toString()))) {
            filtered.add(child);
          } else {
            changedEntries.add([null, stage]);
          }
        }
      } else if (head != null) {
        if (stage == null) {
          changedEntries.add([head, null]);
        } else {
          filtered.add(child);
        }
      }
    }
    return filtered.isNotEmpty
        ? await Future.wait(filtered.map((c) => walkFn(c)))
        : [];
  }

  final entries =
      await walk(
            fs: fs,
            cache: {},
            dir: dir,
            gitdir: gitdir,
            trees: trees,
            map: map,
            reduce: reduce,
            iterate: iterate,
          )
          as _ProcessedEntry?;

  if (changedEntries.isEmpty ||
      entries == null ||
      entries.children == null ||
      entries.children!.isEmpty) {
    return null; // no changes found
  }

  final processedEntries = await _processTreeEntries(
    fs: fs,
    dir: dir,
    gitdir: gitdir,
    entries: entries.children!,
  );

  final treeEntries = processedEntries
      .where((e) => e != null)
      .map(
        (entry) => TreeEntry(
          mode: entry.mode,
          path: entry.path,
          oid: entry.oid,
          type: entry.type,
        ),
      )
      .toList();

  return writeTree(fs: fs, gitdir: gitdir, tree: treeEntries);
}

class _Op {
  final String method;
  final String filepath;
  final String? oid;
  _Op({required this.method, required this.filepath, this.oid});
}

Future<void> applyTreeChanges({
  required FS fs,
  required String dir,
  required String gitdir,
  required String stashCommit,
  required String parentCommit,
  required bool wasStaged,
}) async {
  final dirRemoved = <String>[];
  final stageUpdated = <Map<String, dynamic>>[];

  final ops = await walk(
    fs: fs,
    cache: {},
    dir: dir,
    gitdir: gitdir,
    trees: [
      TREE(ref: parentCommit),
      TREE(ref: stashCommit),
    ],
    map: (filepath, entries) async {
      final parent = entries[0];
      final stash = entries[1];

      if (filepath == '.' ||
          (await GitIgnoreManager.isIgnored(
            fs: fs,
            dir: dir,
            gitdir: gitdir,
            filepath: filepath,
          ))) {
        return null;
      }
      final type = stash != null ? await stash.type() : await parent!.type();
      if (type != 'tree' && type != 'blob') {
        return null;
      }

      if (stash == null && parent != null) {
        final method = type == 'tree' ? 'rmdir' : 'rm';
        if (type == 'tree') dirRemoved.add(filepath);
        if (type == 'blob' && wasStaged) {
          stageUpdated.add({'filepath': filepath, 'oid': await parent.oid()});
        }
        return _Op(method: method, filepath: filepath);
      }

      if (stash != null) {
        // Should always be true if parent was null and it wasn't ignored
        final oid = await stash.oid();
        if (parent == null || (await parent.oid()) != oid) {
          if (type == 'tree') {
            return _Op(method: 'mkdir', filepath: filepath);
          } else {
            if (wasStaged) {
              Stat? stats;
              try {
                stats = await fs.lstat(join(dir, filepath));
              } catch (e) {
                /* may not exist yet */
              }
              stageUpdated.add({
                'filepath': filepath,
                'oid': oid,
                'stat': stats,
              });
            }
            return _Op(method: 'write', filepath: filepath, oid: oid);
          }
        }
      }
      return null;
    },
  );

  await acquireLock(dir, () async {
    for (final op in ops.whereType<_Op>()) {
      final currentFilepath = join(dir, op.filepath);
      switch (op.method) {
        case 'rmdir':
          await fs.rmdir(currentFilepath);
          break;
        case 'mkdir':
          await fs.mkdir(currentFilepath);
          break;
        case 'rm':
          await fs.rm(currentFilepath);
          break;
        case 'write':
          if (!dirRemoved.any(
            (removedDir) => currentFilepath.startsWith(removedDir),
          )) {
            final result = await readObject(
              fs: fs,
              cache: {},
              gitdir: gitdir,
              oid: op.oid!,
            );
            if (await fs.exists(currentFilepath)) {
              await fs.rm(currentFilepath);
            }
            await fs.write(currentFilepath, result.object);
          }
          break;
      }
    }
  });

  await GitIndexManager.acquire(
    fs: fs,
    gitdir: gitdir,
    cache: {},
    callback: (index) async {
      for (var item in stageUpdated) {
        index.insert(
          filepath: item['filepath'],
          stat: item['stat'],
          oid: item['oid'],
        );
      }
    },
  );
}
