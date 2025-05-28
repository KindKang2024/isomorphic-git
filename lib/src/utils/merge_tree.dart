import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../commands/tree.dart';
import '../commands/walk.dart';
import '../errors/merge_conflict_error.dart';
import '../errors/merge_not_supported_error.dart';
import '../models/git_tree.dart';
import '../utils/basename.dart';
import '../utils/join.dart';
import '../utils/merge_file.dart';
import '../utils/modified.dart';
import '../models/file_system.dart';

Future<String> mergeTree({
  required FileSystem fs,
  required Map<String, dynamic> cache,
  String? dir,
  required String gitdir,
  required IndexManager index,
  required String ourOid,
  required String baseOid,
  required String theirOid,
  String ourName = 'ours',
  String baseName = 'base',
  String theirName = 'theirs',
  bool dryRun = false,
  bool abortOnConflict = true,
  MergeDriverCallback? mergeDriver,
}) async {
  final ourTree = TREE(ref: ourOid);
  final baseTree = TREE(ref: baseOid);
  final theirTree = TREE(ref: theirOid);

  final unmergedFiles = <String>[];
  final bothModified = <String>[];
  final deleteByUs = <String>[];
  final deleteByTheirs = <String>[];

  final results = await walk(
    fs: fs,
    cache: cache,
    dir: dir,
    gitdir: gitdir,
    trees: [ourTree, baseTree, theirTree],
    map: (filepath, entries) async {
      final ours = entries[0];
      final base = entries[1];
      final theirs = entries[2];

      final path = basename(filepath);
      final ourChange = await modified(ours, base);
      final theirChange = await modified(theirs, base);

      if (!ourChange && !theirChange) {
        return TreeEntry(
          mode: await base!.mode(),
          path: path,
          oid: await base.oid(),
          type: await base.type(),
        );
      }

      if (!ourChange && theirChange) {
        if (theirs == null && await ours!.type() == 'tree') {
          return TreeEntry(
            mode: await ours.mode(),
            path: path,
            oid: await ours.oid(),
            type: await ours.type(),
          );
        }
        return theirs != null
            ? TreeEntry(
                mode: await theirs.mode(),
                path: path,
                oid: await theirs.oid(),
                type: await theirs.type(),
              )
            : null;
      }

      if (ourChange && !theirChange) {
        if (ours == null && await theirs!.type() == 'tree') {
          return TreeEntry(
            mode: await theirs.mode(),
            path: path,
            oid: await theirs.oid(),
            type: await theirs.type(),
          );
        }
        return ours != null
            ? TreeEntry(
                mode: await ours.mode(),
                path: path,
                oid: await ours.oid(),
                type: await ours.type(),
              )
            : null;
      }

      if (ourChange && theirChange) {
        if (ours != null &&
            base != null &&
            theirs != null &&
            await ours.type() == 'blob' &&
            await base.type() == 'blob' &&
            await theirs.type() == 'blob') {
          final r = await _mergeBlobs(
            fs: fs,
            gitdir: gitdir,
            path: path,
            ours: ours,
            base: base,
            theirs: theirs,
            ourName: ourName,
            baseName: baseName,
            theirName: theirName,
            mergeDriver: mergeDriver,
          );

          if (!r.cleanMerge) {
            unmergedFiles.add(filepath);
            bothModified.add(filepath);
            if (!abortOnConflict) {
              final baseOid_ = await base.oid();
              final ourOid_ = await ours.oid();
              final theirOid_ = await theirs.oid();

              await index.delete(filepath: filepath);

              await index.insert(filepath: filepath, oid: baseOid_, stage: 1);
              await index.insert(filepath: filepath, oid: ourOid_, stage: 2);
              await index.insert(filepath: filepath, oid: theirOid_, stage: 3);
            }
          } else if (!abortOnConflict) {
            await index.insert(
              filepath: filepath,
              oid: r.mergeResult.oid,
              stage: 0,
            );
          }
          return r.mergeResult;
        }

        if (base != null &&
            ours == null &&
            theirs != null &&
            await base.type() == 'blob' &&
            await theirs.type() == 'blob') {
          unmergedFiles.add(filepath);
          deleteByUs.add(filepath);
          if (!abortOnConflict) {
            final baseOid_ = await base.oid();
            final theirOid_ = await theirs.oid();

            await index.delete(filepath: filepath);

            await index.insert(filepath: filepath, oid: baseOid_, stage: 1);
            await index.insert(filepath: filepath, oid: theirOid_, stage: 3);
          }
          return TreeEntry(
            mode: await theirs.mode(),
            oid: await theirs.oid(),
            type: 'blob',
            path: path,
          );
        }

        if (base != null &&
            ours != null &&
            theirs == null &&
            await base.type() == 'blob' &&
            await ours.type() == 'blob') {
          unmergedFiles.add(filepath);
          deleteByTheirs.add(filepath);
          if (!abortOnConflict) {
            final baseOid_ = await base.oid();
            final ourOid_ = await ours.oid();

            await index.delete(filepath: filepath);

            await index.insert(filepath: filepath, oid: baseOid_, stage: 1);
            await index.insert(filepath: filepath, oid: ourOid_, stage: 2);
          }
          return TreeEntry(
            mode: await ours.mode(),
            oid: await ours.oid(),
            type: 'blob',
            path: path,
          );
        }

        if (base != null &&
            ours == null &&
            theirs == null &&
            await base.type() == 'blob') {
          return null;
        }

        throw MergeNotSupportedError();
      }
      return null; // Should be unreachable
    },
    reduce: (unmergedFiles.isNotEmpty && (dir == null || abortOnConflict))
        ? null
        : (parent, children) async {
            final entries = children.whereType<TreeEntry>().toList();

            if (parent == null) return null;

            if (parent.type == 'tree' && entries.isEmpty) return null;

            if (entries.isNotEmpty) {
              final tree = GitTree(entries);
              final object = tree.toObject();
              final oid = await writeObject(
                fs: fs,
                gitdir: gitdir,
                type: 'tree',
                object: object,
                dryRun: dryRun,
              );
              return TreeEntry(
                mode: parent.mode,
                path: parent.path,
                oid: oid,
                type: parent.type,
              );
            }
            return parent;
          },
  );

  if (unmergedFiles.isNotEmpty) {
    if (dir != null && !abortOnConflict) {
      await walk(
        fs: fs,
        cache: cache,
        dir: dir,
        gitdir: gitdir,
        trees: [TREE(ref: results.oid!)],
        map: (filepath, entries) async {
          final entry = entries[0]!;
          final path = join(dir, filepath);
          if (await entry.type() == 'blob') {
            final mode = await entry.mode();
            final content = utf8.decode(await entry.content());
            await fs.write(path, content, mode: mode);
          }
          return true;
        },
      );
    }
    throw MergeConflictError(
      unmergedFiles,
      bothModified,
      deleteByUs,
      deleteByTheirs,
    );
  }
  return results.oid!;
}

class _MergeBlobsResult {
  final bool cleanMerge;
  final TreeEntry mergeResult;
  _MergeBlobsResult({required this.cleanMerge, required this.mergeResult});
}

Future<_MergeBlobsResult> _mergeBlobs({
  required FileSystem fs,
  required String gitdir,
  required String path,
  required WalkerEntry ours,
  required WalkerEntry base,
  required WalkerEntry theirs,
  String? ourName,
  String? baseName,
  String? theirName,
  bool dryRun = false,
  MergeDriverCallback? mergeDriver,
}) async {
  mergeDriver ??= mergeFile;
  const type = 'blob';

  final mode = (await base.mode()) == (await ours.mode())
      ? await theirs.mode()
      : await ours.mode();

  if (await ours.oid() == await theirs.oid()) {
    return _MergeBlobsResult(
      cleanMerge: true,
      mergeResult: TreeEntry(
        mode: mode,
        path: path,
        oid: await ours.oid(),
        type: type,
      ),
    );
  }

  if (await ours.oid() == await base.oid()) {
    return _MergeBlobsResult(
      cleanMerge: true,
      mergeResult: TreeEntry(
        mode: mode,
        path: path,
        oid: await theirs.oid(),
        type: type,
      ),
    );
  }

  if (await theirs.oid() == await base.oid()) {
    return _MergeBlobsResult(
      cleanMerge: true,
      mergeResult: TreeEntry(
        mode: mode,
        path: path,
        oid: await ours.oid(),
        type: type,
      ),
    );
  }

  final ourContent = utf8.decode(await ours.content());
  final baseContent = utf8.decode(await base.content());
  final theirContent = utf8.decode(await theirs.content());

  final result = await mergeDriver(
    branches: [baseName ?? 'base', ourName ?? 'ours', theirName ?? 'theirs'],
    contents: [baseContent, ourContent, theirContent],
    path: path,
  );

  final oid = await writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'blob',
    object: Uint8List.fromList(utf8.encode(result.mergedText)),
    dryRun: dryRun,
  );

  return _MergeBlobsResult(
    cleanMerge: result.cleanMerge,
    mergeResult: TreeEntry(mode: mode, path: path, oid: oid, type: type),
  );
}
