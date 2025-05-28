import 'dart:async';

import 'package:isomorphic_git/src/models/file_system.dart';

import '../errors/invalid_filepath_error.dart';
import '../errors/not_found_error.dart';
import '../errors/object_type_error.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart' as read_object;
import '../utils/resolve_tree.dart';

Future<String> resolveFilepath({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  required String filepath,
}) async {
  if (filepath.startsWith('/')) {
    throw InvalidFilepathError('leading-slash');
  } else if (filepath.endsWith('/')) {
    throw InvalidFilepathError('trailing-slash');
  }

  String currentOid = oid;
  final result = await resolveTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: currentOid,
  );
  final tree = result.tree;

  if (filepath == '') {
    currentOid = result.oid;
  } else {
    final pathArray = filepath.split('/');
    currentOid = await _resolveFilepath(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      tree: tree,
      pathArray: pathArray,
      oid: oid, // Pass original oid for error reporting
      filepath: filepath,
    );
  }
  return currentOid;
}

Future<String> _resolveFilepath({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required GitTree tree,
  required List<String> pathArray,
  required String oid, // Original oid for error context
  required String filepath,
}) async {
  final name = pathArray.removeAt(0);

  for (final entry in tree) {
    if (entry.path == name) {
      if (pathArray.isEmpty) {
        return entry.oid;
      } else {
        final objResult = await read_object.readObject(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          oid: entry.oid,
        );

        if (objResult.type != 'tree') {
          throw ObjectTypeError(
            oid: oid,
            actual: objResult.type,
            expected: 'tree',
            filepath: filepath,
          );
        }
        var newTree = GitTree.from(objResult.object);
        return _resolveFilepath(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          tree: newTree,
          pathArray: pathArray,
          oid: oid,
          filepath: filepath,
        );
      }
    }
  }
  throw NotFoundError('file or directory found at "$oid:$filepath"');
}
