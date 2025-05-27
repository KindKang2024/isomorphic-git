import 'dart:async';

import '../models/git_tree.dart';
import '../storage/read_object.dart';
import '../utils/join.dart';
import '../utils/resolve_tree.dart';
import '../models/fs.dart';

const EMPTY_OID = 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391';

Future<String?> resolveFileIdInTree({
  required FS fs,
  required Map<String, dynamic> cache,
  required String gitdir,
  required String oid,
  required String fileId,
}) async {
  if (fileId == EMPTY_OID) return null;

  final _oid = oid;
  String? filepath;
  final result = await resolveTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  final tree = result.tree;

  if (fileId == result.oid) {
    filepath = result.path;
  } else {
    final filepathsResult = await _resolveFileId(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      tree: tree,
      fileId: fileId,
      oid: _oid,
    );
    if (filepathsResult.isEmpty) {
      filepath = null;
    } else if (filepathsResult.length == 1) {
      filepath = filepathsResult[0];
    } else {
      // If multiple paths are found, behavior might need clarification based on use case.
      // For now, returning the first one, or consider throwing an error or returning List<String>.
      filepath = filepathsResult[0];
    }
  }
  return filepath;
}

Future<List<String>> _resolveFileId({
  required FS fs,
  required Map<String, dynamic> cache,
  required String gitdir,
  required GitTree tree,
  required String fileId,
  required String oid,
  List<String>? filepaths,
  String parentPath = '',
}) async {
  filepaths ??= [];
  final walks = <Future<void>>[];

  for (final entry in tree.entries) {
    if (entry.oid == fileId) {
      final resultPath = join(parentPath, entry.path);
      filepaths.add(resultPath);
    } else if (entry.type == 'tree') {
      final future =
          readObject(
            fs: fs,
            cache: cache,
            gitdir: gitdir,
            oid: entry.oid,
          ).then((readResult) {
            return _resolveFileId(
              fs: fs,
              cache: cache,
              gitdir: gitdir,
              tree: GitTree.from(readResult.object),
              fileId: fileId,
              oid: oid,
              filepaths: filepaths, // Pass the same list to accumulate results
              parentPath: join(parentPath, entry.path),
            );
          });
      walks.add(future.then((_) {})); // Ensure the future completes
    }
  }

  await Future.wait(walks);
  return filepaths;
}
