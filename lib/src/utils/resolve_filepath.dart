import 'dart:async';

import '../errors/invalid_filepath_error.dart';
import '../errors/not_found_error.dart';
import '../errors/object_type_error.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart';
import '../utils/resolve_tree.dart';
import '../models/fs.dart';

Future<String> resolveFilepath({
  required FS fs,
  required Map<String, dynamic> cache,
  required String gitdir,
  required String oid,
  required String filepath,
}) async {
  if (filepath.startsWith('/')) {
    throw InvalidFilepathError('leading-slash');
  } else if (filepath.endsWith('/')) {
    throw InvalidFilepathError('trailing-slash');
  }

  final _oid = oid;
  final result = await resolveTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  var tree = result.tree;
  var currentOid = result.oid; // oid of the current tree being processed

  if (filepath == '') {
    return currentOid;
  } else {
    final pathArray = filepath.split('/');
    currentOid = await _resolveFilepathRecursive(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      tree: tree,
      pathArray: pathArray,
      originalOid: _oid, // Pass the original OID for error reporting
      originalFilepath:
          filepath, // Pass the original filepath for error reporting
    );
  }
  return currentOid;
}

Future<String> _resolveFilepathRecursive({
  required FS fs,
  required Map<String, dynamic> cache,
  required String gitdir,
  required GitTree tree,
  required List<String> pathArray,
  required String
  originalOid, // OID of the starting tree/commit for error context
  required String originalFilepath, // Full filepath for error context
}) async {
  final name = pathArray.removeAt(0);

  for (final entry in tree.entries) {
    if (entry.path == name) {
      if (pathArray.isEmpty) {
        return entry.oid;
      } else {
        final objectResult = await readObject(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          oid: entry.oid,
        );
        if (objectResult.type != 'tree') {
          throw ObjectTypeError(
            oid: entry.oid, // oid of the object that is not a tree
            type: objectResult.type,
            expected: 'tree',
            filepath: originalFilepath,
          );
        }
        final nextTree = GitTree.from(objectResult.object);
        return _resolveFilepathRecursive(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          tree: nextTree,
          pathArray: pathArray,
          originalOid: originalOid,
          originalFilepath: originalFilepath,
        );
      }
    }
  }
  throw NotFoundError(
    'file or directory not found at "$originalOid:$originalFilepath"',
  );
}
