import 'dart:io';
import '../errors/object_type_error.dart';
import '../managers/git_ref_manager.dart';
import '../managers/git_shallow_manager.dart';
import '../models/git_annotated_tag.dart';
import '../models/git_commit.dart';
import '../storage/read_object.dart';
import 'package:path/path.dart' as p;

Future<Set<String>> listCommitsAndTags({
  required Directory fs,
  required dynamic cache,
  String? dir,
  String? gitdir,
  required Iterable<String> start,
  required Iterable<String> finish,
}) async {
  final gitDirectory = dir != null ? p.join(dir, '.git') : gitdir!;
  final shallows = await GitShallowManager.read(fs: fs, gitdir: gitDirectory);
  final startingSet = <String>{};
  final finishingSet = <String>{};

  for (final ref in start) {
    startingSet.add(
      await GitRefManager.resolve(fs: fs, gitdir: gitDirectory, ref: ref),
    );
  }

  for (final ref in finish) {
    try {
      final oid = await GitRefManager.resolve(
        fs: fs,
        gitdir: gitDirectory,
        ref: ref,
      );
      finishingSet.add(oid);
    } catch (e) {
      // We may not have these refs locally
    }
  }

  final visited = <String>{};

  Future<void> walk(String oid) async {
    visited.add(oid);
    final objectRead = await readObject(
      fs: fs,
      cache: cache,
      gitdir: gitDirectory,
      oid: oid,
    );

    if (objectRead.type == 'tag') {
      final tag = GitAnnotatedTag.fromBytes(objectRead.object);
      final commit = tag.object;
      return walk(commit);
    }

    if (objectRead.type != 'commit') {
      throw ObjectTypeError(oid, objectRead.type, 'commit');
    }

    if (!shallows.contains(oid)) {
      final commit = GitCommit.fromBytes(objectRead.object);
      final parents = commit.parents;
      for (var parentOid in parents) {
        if (!finishingSet.contains(parentOid) && !visited.contains(parentOid)) {
          await walk(parentOid);
        }
      }
    }
  }

  for (final oid in startingSet) {
    await walk(oid);
  }

  return visited;
}
