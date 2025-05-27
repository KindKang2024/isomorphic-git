import 'dart:collection';
import 'dart:io';

import '../errors/max_depth_error.dart';
import '../errors/missing_parameter_error.dart';
import '../errors/object_type_error.dart';
import '../managers/git_shallow_manager.dart';
import '../models/git_commit.dart';
import '../storage/read_object.dart';

Future<bool> isDescendent({
  required Directory fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  required String ancestor,
  required int depth,
}) async {
  final shallows = await GitShallowManager.read(fs: fs, gitdir: gitdir);
  if (oid == null) {
    throw MissingParameterError('oid');
  }
  if (ancestor == null) {
    throw MissingParameterError('ancestor');
  }
  // If you don't like this behavior, add your own check.
  // Edge cases are hard to define a perfect solution.
  if (oid == ancestor) return false;

  final queue = Queue<String>();
  queue.add(oid);
  final visited = <String>{};
  var searchdepth = 0;

  while (queue.isNotEmpty) {
    if (searchdepth++ == depth && depth != -1) {
      throw MaxDepthError(depth);
    }
    final currentOid = queue.removeFirst();
    final objectRead = await readObject(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: currentOid,
    );

    if (objectRead.type != 'commit') {
      throw ObjectTypeError(currentOid, objectRead.type, 'commit');
    }

    final commit = GitCommit.fromBytes(objectRead.object).parse();

    for (final parent in commit.parents) {
      if (parent == ancestor) return true;
    }

    if (!shallows.contains(currentOid)) {
      for (final parent in commit.parents) {
        if (!visited.contains(parent)) {
          queue.add(parent);
          visited.add(parent);
        }
      }
    }
  }
  return false;
}
