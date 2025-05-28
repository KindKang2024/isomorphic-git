import 'dart:async';

import '../models/git_tree.dart';
import '../storage/read_object.dart' as read_object;
import '../models/file_system.dart';
import '../utils/join.dart';
import '../utils/resolve_tree.dart';

// The empty file content object id
const String EMPTY_OID = 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391';

Future<dynamic> resolveFileIdInTree({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  required String fileId,
}) async {
  if (fileId == EMPTY_OID) return null;

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
    var resolvedFilepaths = await _resolveFileId(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      tree: tree,
      fileId: fileId,
      oid: oid,
      filepaths: [],
    );
    if (resolvedFilepaths.length == 0) {
      filepath = null;
    } else if (resolvedFilepaths.length == 1) {
      filepath = resolvedFilepaths[0];
    } else {
      // If multiple filepaths are found, return the list
      return resolvedFilepaths;
    }
  }
  return filepath;
}

Future<List<String>> _resolveFileId({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required GitTree tree,
  required String fileId,
  required String oid,
  required List<String> filepaths,
  String parentPath = '',
}) async {
  List<Future<void>> walks = [];

  for (var entry in tree.entries) {
    if (entry.oid == fileId) {
      filepaths.add(join([parentPath, entry.path]));
    } else if (entry.type == 'tree') {
      walks.add(
        read_object
            .readObject(fs: fs, cache: cache, gitdir: gitdir, oid: entry.oid)
            .then((objectResult) {
              return _resolveFileId(
                fs: fs,
                cache: cache,
                gitdir: gitdir,
                tree: GitTree.from(objectResult.object),
                fileId: fileId,
                oid: oid,
                filepaths:
                    filepaths, // Pass the same list to accumulate results
                parentPath: join([parentPath, entry.path]),
              );
            })
            .then((_) {}), // Ensure the future completes
      );
    }
  }

  await Future.wait(walks);
  return filepaths;
}
