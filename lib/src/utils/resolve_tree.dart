import 'dart:async';

import 'package:isomorphic_git/src/models/file_system.dart';

import '../errors/object_type_error.dart';
import '../models/git_annotated_tag.dart';
import '../models/git_commit.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart' as read_object;

class ResolveTreeResult {
  final GitTree tree;
  final String oid;
  final String? path; // Added path for consistency with resolveFileIdInTree

  ResolveTreeResult({required this.tree, required this.oid, this.path});
}

Future<ResolveTreeResult> resolveTree({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
}) async {
  // Empty tree - bypass `readObject`
  if (oid == '4b825dc642cb6eb9a060e54bf8d69288fbee4904') {
    return ResolveTreeResult(tree: GitTree.from([]), oid: oid);
  }

  var result = await read_object.readObject(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  var type = result.type;
  var object = result.object;
  String currentOid = oid;

  if (type == 'tag') {
    currentOid = GitAnnotatedTag.from(object).parse()['object'];
    return resolveTree(fs: fs, cache: cache, gitdir: gitdir, oid: currentOid);
  }

  if (type == 'commit') {
    currentOid = GitCommit.from(object).parse()['tree'];
    return resolveTree(fs: fs, cache: cache, gitdir: gitdir, oid: currentOid);
  }

  if (type != 'tree') {
    throw ObjectTypeError(oid: currentOid, actual: type, expected: 'tree');
  }

  return ResolveTreeResult(tree: GitTree.from(object), oid: currentOid);
}
