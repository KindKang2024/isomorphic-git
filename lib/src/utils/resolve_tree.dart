import 'dart:async';

import '../errors/object_type_error.dart';
import '../models/git_annotated_tag.dart';
import '../models/git_commit.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart';
import '../models/fs.dart';

class ResolveTreeResult {
  final GitTree tree;
  final String oid;
  // The original JS version also had a `path` property in one of the return paths
  // but it seems to be specific to resolveFileIdInTree logic using resolveTree.
  // For a generic resolveTree, path isn't directly relevant unless it refers to the path to *this* tree if nested.
  // For now, keeping it simple as per the primary function of resolveTree.
  String? path;

  ResolveTreeResult({required this.tree, required this.oid, this.path});
}

const String EMPTY_TREE_OID = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';

Future<ResolveTreeResult> resolveTree({
  required FS fs,
  required Map<String, dynamic> cache,
  required String gitdir,
  required String oid,
}) async {
  if (oid == EMPTY_TREE_OID) {
    return ResolveTreeResult(tree: GitTree.from([]), oid: oid);
  }

  final objectResult = await readObject(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  final type = objectResult.type;
  final object = objectResult.object;
  String currentOid = oid;

  if (type == 'tag') {
    currentOid = GitAnnotatedTag.from(object).parse().object;
    return resolveTree(fs: fs, cache: cache, gitdir: gitdir, oid: currentOid);
  }

  if (type == 'commit') {
    currentOid = GitCommit.from(object).parse().tree;
    return resolveTree(fs: fs, cache: cache, gitdir: gitdir, oid: currentOid);
  }

  if (type != 'tree') {
    throw ObjectTypeError(oid: oid, type: type, expected: 'tree');
  }

  return ResolveTreeResult(tree: GitTree.from(object), oid: currentOid);
}
