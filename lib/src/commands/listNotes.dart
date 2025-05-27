import 'dart:io';

import '../commands/read_tree.dart';
import '../errors/not_found_error.dart';
import '../managers/git_ref_manager.dart';

class GitNote {
  String target;
  String note;
  GitNote({required this.target, required this.note});
}

Future<List<GitNote>> listNotes({
  required Directory fs,
  required dynamic cache,
  required String gitdir,
  required String ref,
}) async {
  String? parentOid;
  try {
    parentOid = await GitRefManager.resolve(gitdir: gitdir, fs: fs, ref: ref);
  } catch (e) {
    if (e is NotFoundError) {
      return [];
    }
    rethrow;
  }

  final treeResult = await readTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: parentOid!,
  );

  final notes = treeResult.tree
      .map((entry) => GitNote(target: entry.path, note: entry.oid))
      .toList();
  return notes;
}
