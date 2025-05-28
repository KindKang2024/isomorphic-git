import '../commands/commit.dart';
import '../commands/read_tree.dart';
import '../commands/write_tree.dart';
import '../errors/not_found_error.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/callbacks.dart';

class RemoveNoteAuthor {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  RemoveNoteAuthor({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });
}

class RemoveNoteCommitter {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  RemoveNoteCommitter({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });
}

Future<String> removeNote({
  required FileSystem fs,
  required dynamic cache,
  SignCallback? onSign,
  required String gitdir,
  String ref = 'refs/notes/commits',
  required String oid,
  required RemoveNoteAuthor author,
  required RemoveNoteCommitter committer,
  String? signingKey,
}) async {
  // Get the current note commit
  String? parent;
  try {
    parent = await GitRefManager.resolve(
      gitdir: gitdir,
      fs: fs,
      ref: ref,
    );
  } catch (err) {
    if (err is! NotFoundError) {
      rethrow;
    }
  }

  // I'm using the "empty tree" magic number here for brevity
  final result = await readTree(
    fs: fs,
    gitdir: gitdir,
    oid: parent ?? '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
  );
  
  // Remove the note blob entry from the tree
  final tree = result.tree.where((entry) => entry.path != oid).toList();

  // Create the new note tree
  final treeOid = await writeTree(
    fs: fs,
    gitdir: gitdir,
    tree: tree,
  );

  // Create the new note commit
  final commitOid = await commit(
    fs: fs,
    cache: cache,
    onSign: onSign,
    gitdir: gitdir,
    ref: ref,
    tree: treeOid,
    parent: parent != null ? [parent] : null,
    message: "Note removed by 'isomorphic-git removeNote'\n",
    authorInput: CommitAuthor(
      name: author.name,
      email: author.email,
      timestamp: author.timestamp,
      timezoneOffset: author.timezoneOffset,
    ),
    committerInput: CommitCommitter(
      name: committer.name,
      email: committer.email,
      timestamp: committer.timestamp,
      timezoneOffset: committer.timezoneOffset,
    ),
    signingKey: signingKey,
  );

  return commitOid;
}