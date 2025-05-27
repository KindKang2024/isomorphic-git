import 'dart:typed_data';
import 'dart:convert'; // For utf8.encode

import '../commands/commit.dart' as commit_command;
import '../commands/read_tree.dart' as read_tree_command;
import '../commands/write_tree.dart' as write_tree_command;
import '../errors/already_exists_error.dart';
import '../errors/not_found_error.dart';
import '../managers/git_ref_manager.dart';
import '../storage/write_object.dart' as write_object_command;
import '../models/fs.dart'; // Assuming FsModel exists
import '../models/git_tree.dart'; // Assuming GitTree and TreeEntry exist
import '../utils/typedefs.dart'; // For SignCallback and other potential typedefs

class AddNoteAuthor {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  AddNoteAuthor({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });
}

class AddNoteCommitter {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  AddNoteCommitter({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });
}

Future<String> addNote({
  required FsModel fs,
  required Map<String, dynamic> cache,
  SignCallback? onSign,
  required String gitdir,
  required String ref,
  required String oid,
  required dynamic note, // String or Uint8List
  bool force = false,
  required AddNoteAuthor author,
  required AddNoteCommitter committer,
  String? signingKey,
}) async {
  String? parent;
  try {
    parent = await GitRefManager.resolve(gitdir: gitdir, fs: fs, ref: ref);
  } catch (e) {
    if (e is! NotFoundError) {
      rethrow;
    }
  }

  // I'm using the "empty tree" magic number here for brevity
  final readTreeResult = await read_tree_command.readTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: parent ?? '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
  );
  // Assuming readTreeResult has a 'tree' property of type List<TreeEntry>
  List<TreeEntry> tree = List<TreeEntry>.from(readTreeResult.tree);

  if (force) {
    tree.removeWhere((entry) => entry.path == oid);
  } else {
    for (final entry in tree) {
      if (entry.path == oid) {
        throw AlreadyExistsError('note', oid);
      }
    }
  }

  Uint8List noteData;
  if (note is String) {
    noteData = utf8.encode(note);
  } else if (note is Uint8List) {
    noteData = note;
  } else {
    throw ArgumentError('note must be a String or Uint8List');
  }

  final noteOid = await write_object_command.writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'blob',
    object: noteData,
    format: 'content',
  );

  tree.add(TreeEntry(mode: '100644', path: oid, oid: noteOid, type: 'blob'));
  final treeOid = await write_tree_command.writeTree(
    fs: fs,
    gitdir: gitdir,
    tree: tree,
  );

  final commitOid = await commit_command.commit(
    fs: fs,
    cache: cache,
    onSign: onSign,
    gitdir: gitdir,
    ref: ref, // This might need to be null if we are not updating a ref directly
    treeOid: treeOid,
    parents: parent != null ? [parent] : [],
    message: "Note added by 'isomorphic-git addNote'\n",
    author: 오른쪽GitAuthor(name: author.name, email: author.email, timestamp: author.timestamp, timezoneOffset: author.timezoneOffset),
    committer: 오른쪽GitCommitter(name: committer.name, email: committer.email, timestamp: committer.timestamp, timezoneOffset: committer.timezoneOffset),
    signingKey: signingKey,
  );

  return commitOid;
}

// Placeholder for an assumed GitAuthor class, adjust as necessary
class 오른쪽GitAuthor {
  String name;
  String email;
  int timestamp;
  int timezoneOffset;
  오른쪽GitAuthor({required this.name, required this.email, required this.timestamp, required this.timezoneOffset});
}
// Placeholder for an assumed GitCommitter class, adjust as necessary
class 오른쪽GitCommitter {
  String name;
  String email;
  int timestamp;
  int timezoneOffset;
  오른쪽GitCommitter({required this.name, required this.email, required this.timestamp, required this.timezoneOffset});
} 