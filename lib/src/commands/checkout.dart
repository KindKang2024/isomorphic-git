import 'dart:async';
import 'dart:io' as io; // For FileSystemEntity type checks if needed

import '../commands/stage.dart' as stage_command;
import '../commands/tree.dart' as tree_command;
import '../commands/workdir.dart' as workdir_command;
import '../commands/walk.dart' as walk_command;

import '../errors/checkout_conflict_error.dart';
import '../errors/commit_not_fetched_error.dart';
import '../errors/internal_error.dart';
import '../errors/not_found_error.dart';

import '../managers/git_config_manager.dart';
import '../managers/git_index_manager.dart';
import '../managers/git_ref_manager.dart';
import '../storage/read_object.dart' as read_object_command;

import '../utils/flat.dart';
import '../utils/worth_walking.dart';
import '../utils/path_utils.dart' as path_utils; // Assuming path utility

import '../models/fs.dart'; // Assuming FsModel exists
import '../utils/typedefs.dart'; // For ProgressCallback, PostCheckoutCallback

// Helper function to mimic the analyze sub-function in JS
// This is a significant piece of logic and might be better in its own file
Future<List<List<dynamic>>> _analyzeCheckoutOps({
  required FsModel fs,
  required Map<String, dynamic> cache,
  ProgressCallback? onProgress,
  required String dir,
  required String gitdir,
  required String ref,
  required bool force,
  List<String>? filepaths,
}) async {
  // This is a placeholder for the complex logic in the original `analyze` function.
  // It involves walking trees, comparing with workdir and index, etc.
  // For now, it returns an empty list, but this needs to be fully implemented.
  // The `_walk` command and its comparators would be heavily used here.

  final fromWalker = filepaths != null
      ? STAGE() // This is a simplification. The original uses a complex setup.
      : TREE(ref: ref);
  final toWalker = WORKDIR();

  // The `trees` parameter in `_walk` needs careful construction based on `filepaths`
  List<dynamic> trees = [fromWalker, toWalker, STAGE()];

  List<walk_command.WalkEntry> walkResults = await walk_command.walk(
    fs: fs,
    cache: cache,
    dir: dir,
    gitdir: gitdir,
    trees: trees,
    map: (String filepath, List<walk_command.GitTreeWalkerEntry?> entries) async {
      // This mapping function is the core of the analysis.
      // It determines the operations needed based on the state of the file/dir
      // in the source tree, workdir, and index.
      // The logic here is intricate and involves comparing OIDs, modes, and types.

      // Placeholder logic:
      if (entries[0] != null && entries[1] == null) {
        return [
          filepath,
          if (entries[0]!.type == 'tree') 'mkdir' else 'new',
          entries[0]!.oid,
          entries[0]!.mode,
        ];
      } else if (entries[0] == null && entries[1] != null) {
        return [filepath, 'delete', entries[1]!.oid, entries[1]!.mode];
      } else if (entries[0] != null && entries[1] != null) {
        if (entries[0]!.oid != entries[1]!.oid) {
          return [
            filepath,
            'modify',
            entries[0]!.oid,
            entries[0]!.mode,
          ]; // And original OID from entries[1]
        }
      }
      return null; // No change
    },
    // reduce: (parent, children) => { ... }, // Optional reducer
    iterate: (walk, children) async {
      // The default iteration logic might be sufficient, or it might need customization.
      // This is a placeholder for potential custom iteration logic.
      return await walk_command.defaultIterate(walk, children);
    },
    // Pass other necessary parameters to _walk
  );

  // Process walkResults to generate the 'ops' list.
  // This part needs to translate the comparisons into actions like:
  // ['delete', path], ['rmdir', path], ['mkdir', path], ['write', path, oid, mode],
  // ['delete-index', path], ['rmdir-index', path],
  // ['conflict', path], ['error', path]
  // The exact structure of 'ops' and its generation is complex.

  List<List<dynamic>> ops = [];
  for (var result in walkResults) {
    // This is highly simplified and needs the full logic from the JS version.
    // The `result` here is the output of the `map` function in `_walk`.
    if (result != null) {
      String filePath = result[0];
      String? op = result[1];
      String? oid = result[2];
      String? mode = result[3];

      if (op == 'new') {
        ops.add(['write', filePath, oid, mode]);
      } else if (op == 'mkdir') {
        ops.add(['mkdir', filePath]);
      } else if (op == 'delete') {
        // Distinguish between file and directory for rmdir
        // This requires knowing if it was a tree or blob
        ops.add(['delete', filePath]); // or 'rmdir'
      } else if (op == 'modify') {
        ops.add([
          'write',
          filePath,
          oid,
          mode,
        ]); // And original OID for index update
      }
    }
  }
  return ops;
}

Future<void> checkout({
  required FsModel fs,
  required Map<String, dynamic> cache,
  ProgressCallback? onProgress,
  PostCheckoutCallback? onPostCheckout,
  required String dir,
  required String gitdir,
  required String ref,
  List<String>? filepaths,
  String?
  remote, // Made nullable as per JS where it might not be used if ref exists
  bool noCheckout = false,
  bool? noUpdateHead, // Nullable, original doesn't specify a default
  bool dryRun = false,
  bool force = false,
  bool track = true,
}) async {
  String? oldOid;
  if (onPostCheckout != null) {
    try {
      oldOid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: 'HEAD');
    } catch (e) {
      oldOid = '0000000000000000000000000000000000000000';
    }
  }

  String targetOid;
  String currentBranchRef = 'refs/heads/$ref';

  try {
    targetOid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: ref);
  } catch (e) {
    if (ref == 'HEAD' || remote == null) {
      // If ref is HEAD and not found, or if remote is not provided, rethrow.
      rethrow;
    }
    // If `ref` doesn't exist, create a new remote tracking branch
    final remoteRef = '$remote/$ref';
    try {
      targetOid = await GitRefManager.resolve(
        fs: fs,
        gitdir: gitdir,
        ref: remoteRef,
      );
    } catch (e2) {
      if (e2 is NotFoundError) {
        throw NotFoundError('Remote ref $remoteRef not found.');
      }
      rethrow;
    }

    if (track) {
      final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
      await config.set('branch.$ref.remote', remote);
      await config.set('branch.$ref.merge', 'refs/heads/$ref');
      await GitConfigManager.save(fs: fs, gitdir: gitdir, config: config);
    }
    // Create a new branch that points at that same commit
    await GitRefManager.writeRef(
      fs: fs,
      gitdir: gitdir,
      ref: currentBranchRef,
      value: targetOid,
    );
  }

  if (!noCheckout) {
    List<List<dynamic>> ops;
    try {
      ops = await _analyzeCheckoutOps(
        fs: fs,
        cache: cache,
        onProgress: onProgress,
        dir: dir,
        gitdir: gitdir,
        ref: targetOid, // Use resolved OID for analysis
        force: force,
        filepaths: filepaths,
      );
    } catch (e) {
      if (e is NotFoundError && e.data['what'] == targetOid) {
        throw CommitNotFetchedError(ref, targetOid);
      }
      rethrow;
    }

    final conflicts = ops
        .where((op) => op[0] == 'conflict')
        .map<String>((op) => op[1] as String)
        .toList();
    if (conflicts.isNotEmpty) {
      throw CheckoutConflictError(conflicts);
    }

    final errors = ops
        .where((op) => op[0] == 'error')
        .map<String>((op) => op[1] as String)
        .toList();
    if (errors.isNotEmpty) {
      throw InternalError(errors.join(', '));
    }

    if (dryRun) {
      if (onPostCheckout != null) {
        await onPostCheckout(
          previousHead: oldOid,
          newHead: targetOid,
          type: filepaths != null && filepaths.isNotEmpty ? 'file' : 'branch',
        );
      }
      return;
    }

    int count = 0;
    final int total = ops.length;

    // Phase 1: Delete files and update index
    await GitIndexManager.acquire(fs: fs, gitdir: gitdir, cache: cache, (
      GitIndex index,
    ) async {
      List<Future<void>> deleteOps = [];
      for (final op in ops) {
        if (op[0] == 'delete' || op[0] == 'delete-index') {
          final String fullpath = op[1] as String;
          final String systemFilepath = path_utils.join(dir, fullpath);
          deleteOps.add(() async {
            if (op[0] == 'delete') {
              // Check if it's a file before attempting to delete
              if (await fs.type(systemFilepath) == FileSystemEntityType.file) {
                await fs.rm(systemFilepath);
              }
            }
            index.delete(filepath: fullpath);
            if (onProgress != null) {
              await onProgress(
                phase: 'Updating workdir',
                loaded: ++count,
                total: total,
              );
            }
          }());
        }
      }
      await Future.wait(deleteOps);
    });

    // Phase 2: Remove directories (cannot be simply parallel)
    await GitIndexManager.acquire(fs: fs, gitdir: gitdir, cache: cache, (
      GitIndex index,
    ) async {
      // Sort paths by depth (descending) to remove nested items first
      ops.sort((a, b) {
        if ((a[0] == 'rmdir' || a[0] == 'rmdir-index') &&
            (b[0] == 'rmdir' || b[0] == 'rmdir-index')) {
          return (b[1] as String)
              .split('/')
              .length
              .compareTo((a[1] as String).split('/').length);
        }
        return 0; // Keep original order for non-rmdir ops
      });

      for (final op in ops) {
        if (op[0] == 'rmdir' || op[0] == 'rmdir-index') {
          final String fullpath = op[1] as String;
          final String systemFilepath = path_utils.join(dir, fullpath);
          try {
            if (op[0] == 'rmdir-index') {
              index.delete(filepath: fullpath);
            }
            // Check if it's a directory and exists before attempting to delete
            if (await fs.type(systemFilepath) ==
                FileSystemEntityType.directory) {
              await fs.rmdir(systemFilepath);
            }

            if (onProgress != null) {
              await onProgress(
                phase: 'Updating workdir',
                loaded: ++count,
                total: total,
              );
            }
          } catch (e) {
            // In JS, there's a check for 'ENOTEMPTY'. Dart's equivalent is io.FileSystemException with specific osError.errorCode
            // This check might need to be more robust depending on FsModel implementation.
            if (e is io.FileSystemException &&
                (e.osError?.errorCode == 39 || e.osError?.errorCode == 66)) {
              // 39: ENOTEMPTY on macOS/Linux, 66 might be Windows
              print(
                'Did not delete $fullpath because directory is not empty. This may be an error or an ignored condition.',
              );
            } else {
              // rethrow; // Or handle more gracefully
              print(
                'Error removing directory $fullpath: $e. This may be an error or an ignored condition.',
              );
            }
          }
        }
      }
    });

    // Phase 3: Create directories
    // Sort paths by depth (ascending) to create parent dirs first
    ops.sort((a, b) {
      if (a[0] == 'mkdir' && b[0] == 'mkdir') {
        return (a[1] as String)
            .split('/')
            .length
            .compareTo((b[1] as String).split('/').length);
      }
      return 0;
    });
    for (final op in ops) {
      if (op[0] == 'mkdir') {
        final String fullpath = op[1] as String;
        final String systemFilepath = path_utils.join(dir, fullpath);
        await fs.mkdir(
          systemFilepath,
          recursive: true,
        ); // recursive true handles parents
        if (onProgress != null) {
          await onProgress(
            phase: 'Updating workdir',
            loaded: ++count,
            total: total,
          );
        }
      }
    }

    // Phase 4: Write files and update index
    await GitIndexManager.acquire(fs: fs, gitdir: gitdir, cache: cache, (
      GitIndex index,
    ) async {
      List<Future<void>> writeOps = [];
      for (final op in ops) {
        if (op[0] == 'write' || op[0] == 'new' || op[0] == 'modify') {
          // 'new' and 'modify' from simplified _analyze
          final String fullpath = op[1] as String;
          final String fileOid = op[2] as String;
          final String mode =
              op[3] as String; // Or int if mode is stored as int
          // final String? originalOid = (op.length > 4) ? op[4] as String? : null; // For index updates if 'modify'

          writeOps.add(() async {
            final objectReadResult = await read_object_command.readObject(
              fs: fs,
              cache: cache,
              gitdir: gitdir,
              oid: fileOid,
            );

            // Ensure parent directory exists
            final parentDir = path_utils.dirname(fullpath);
            if (parentDir.isNotEmpty && parentDir != '.') {
              await fs.mkdir(path_utils.join(dir, parentDir), recursive: true);
            }

            await fs.write(
              path_utils.join(dir, fullpath),
              objectReadResult.object as Uint8List,
            ); // Assuming object is Uint8List
            await fs.chmod(
              path_utils.join(dir, fullpath),
              int.parse(mode, radix: 8),
            ); // Mode from string '644' or '755'

            index.insert(
              filepath: fullpath,
              oid: fileOid,
              mode: mode,
            ); // or use stat info

            if (onProgress != null) {
              await onProgress(
                phase: 'Updating workdir',
                loaded: ++count,
                total: total,
              );
            }
          }());
        }
      }
      await Future.wait(writeOps);
    });
  } // end !noCheckout

  if (!(noUpdateHead ?? false) && filepaths == null) {
    // Only update HEAD if not single file checkout and noUpdateHead is not true
    await GitRefManager.writeSymbolicRef(
      fs: fs,
      gitdir: gitdir,
      ref: 'HEAD',
      value: currentBranchRef,
    );
  }

  if (onPostCheckout != null) {
    await onPostCheckout(
      previousHead: oldOid,
      newHead: targetOid,
      type: filepaths != null && filepaths.isNotEmpty ? 'file' : 'branch',
    );
  }
}

// Dummy STAGE, TREE, WORKDIR, and GitIndex/GitTreeWalkerEntry for placeholder _analyzeCheckoutOps
// These would come from their respective files in a real implementation.
Object STAGE() => Object();
Object TREE({String? ref}) => Object();
Object WORKDIR() => Object();

class GitIndex {
  void delete({required String filepath}) {}
  void insert({
    required String filepath,
    required String oid,
    required String mode,
  }) {}
}

class GitTreeWalkerEntry {
  String oid;
  String type;
  String mode;
  GitTreeWalkerEntry({
    required this.oid,
    required this.type,
    required this.mode,
  });
}

// Assumed FileSystemEntityType for fs.type comparison
class FileSystemEntityType {
  static const file = _Type('file');
  static const directory = _Type('directory');
  static const link = _Type('link');
  static const notFound = _Type('notFound'); // Or similar
  final String _value;
  const FileSystemEntityType._(this._value);
}

class _Type extends FileSystemEntityType {
  const _Type(String val) : super._(val);
}
