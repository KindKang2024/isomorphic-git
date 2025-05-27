import 'dart:io';

import '../models/git_annotated_tag.dart';
import '../models/git_commit.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart';
import 'package:path/path.dart' as p;

Future<Set<String>> listObjects({
  required Directory fs,
  required dynamic cache,
  String? dir,
  String? gitdir,
  required Iterable<String> oids,
}) async {
  final gitDirectory = dir != null ? p.join(dir, '.git') : gitdir!;
  final visited = <String>{};

  Future<void> walk(String oid) async {
    if (visited.contains(oid)) return;
    visited.add(oid);

    final objectRead = await readObject(
      fs: fs,
      cache: cache,
      gitdir: gitDirectory,
      oid: oid,
    );

    if (objectRead.type == 'tag') {
      final tag = GitAnnotatedTag.fromBytes(objectRead.object);
      final obj = tag.object; // In Dart, this is directly the SHA of the object
      await walk(obj);
    } else if (objectRead.type == 'commit') {
      final commit = GitCommit.fromBytes(objectRead.object);
      final tree = commit.tree; // In Dart, this is directly the SHA of the tree
      await walk(tree);
    } else if (objectRead.type == 'tree') {
      final tree = GitTree.fromBytes(objectRead.object);
      for (final entry in tree.entries) {
        if (entry.type == 'blob') {
          visited.add(entry.oid);
        }
        if (entry.type == 'tree') {
          await walk(entry.oid);
        }
      }
    }
  }

  for (final oid in oids) {
    await walk(oid);
  }
  return visited;
}
