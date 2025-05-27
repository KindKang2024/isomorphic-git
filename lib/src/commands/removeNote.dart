import '../commands/commit.dart';
import '../commands/read_tree.dart';
import '../commands/write_tree.dart';
import '../errors/not_found_error.dart';
import '../managers/git_ref_manager.dart';
import '../models/tree_object.dart'; // For TreeEntry

// TODO: Define these types or import them
typedef FileSystem = dynamic; // Placeholder
typedef Cache = dynamic; // Placeholder
typedef SignCallback =
    Future<String> Function(String dataToSign); // Placeholder

class PersonIdent {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  PersonIdent({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'timestamp': timestamp,
    'timezoneOffset': timezoneOffset,
  };
}

Future<String> removeNote({
  required FileSystem fs,
  required Cache cache,
  SignCallback? onSign,
  required String gitdir,
  String ref = 'refs/notes/commits',
  required String oid, // OID of the commit to remove the note from
  required PersonIdent author,
  required PersonIdent committer,
  String? signingKey,
}) async {
  String? parentCommitOid;
  try {
    parentCommitOid = await GitRefManager.resolve(
      gitdir: gitdir,
      fs: fs,
      ref: ref,
    );
  } catch (err) {
    if (err is! NotFoundError) {
      rethrow;
    }
    // If not found, it means no notes ref exists yet, or it's empty.
    // The behavior in JS is to effectively try to read an empty tree if parent is undefined.
  }

  // Read the current notes tree. If no parent, use the empty tree OID.
  final ReadTreeResult readTreeResult = await readTree(
    fs: fs,
    cache: cache, // readTree in Dart needs cache
    gitdir: gitdir,
    oid:
        parentCommitOid ??
        '4b825dc642cb6eb9a060e54bf8d69288fbee4904', // Magic empty tree OID
  );
  List<TreeEntry> currentTreeEntries = readTreeResult.tree;

  // Filter out the entry corresponding to the note (oid is the filename)
  List<TreeEntry> newTreeEntries = currentTreeEntries
      .where((entry) => entry.path != oid)
      .toList();

  // Write the new tree
  final newTreeOid = await writeTree(
    fs: fs,
    gitdir: gitdir,
    tree: newTreeEntries,
    cache:
        cache, // Added cache, assuming writeTree needs it like other commands
  );

  // Create the new commit for the notes ref
  final newCommitOid = await commit(
    fs: fs,
    cache: cache,
    onSign: onSign, // Pass through the onSign callback
    gitdir: gitdir,
    ref: ref, // The notes ref itself
    tree: newTreeOid,
    parents: parentCommitOid != null ? [parentCommitOid] : [],
    message: 'Note removed by \'isomorphic-git removeNote\'\n',
    author: author.toMap(), // Convert PersonIdent to Map
    committer: committer.toMap(), // Convert PersonIdent to Map
    signingKey: signingKey,
  );

  return newCommitOid;
}
