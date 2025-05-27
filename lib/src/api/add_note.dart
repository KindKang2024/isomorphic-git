import 'dart:typed_data';

// import '../typedefs.dart'; // Dart handles types and callbacks

import '../commands/add_note.dart'
    show addNoteInternal; // Assuming _addNote is addNoteInternal
import '../errors/missing_name_error.dart';
import '../models/file_system.dart'; // Assumes FsClient is here
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/normalize_author_object.dart';
import '../utils/normalize_committer_object.dart';

// Define a type for the onSign callback if it's complex
// typedef SignCallback = Future<String> Function(String dataToSign);

// Define Author and Committer data classes if they are not already defined elsewhere
// class PersonDetails {
//   String? name;
//   String? email;
//   int? timestamp;
//   int? timezoneOffset;
//   PersonDetails({this.name, this.email, this.timestamp, this.timezoneOffset});
// }

/// Add or update an object note
Future<String> addNote({
  required dynamic fs, // Should be FsClient
  dynamic onSign, // Should be SignCallback?
  String? dir,
  String? gitdir,
  String ref = 'refs/notes/commits',
  required String oid,
  required dynamic note, // String or Uint8List
  bool? force,
  dynamic author, // Should be PersonDetails?
  dynamic committer, // Should be PersonDetails?
  String? signingKey,
  Map<String, dynamic>? cache,
}) async {
  final effectiveGitdir = gitdir ?? (dir != null ? join(dir, '.git') : null);
  final effectiveCache = cache ?? {};

  if (effectiveGitdir == null) {
    throw ArgumentError('Either dir or gitdir must be provided.');
  }

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);
    assertParameter('note', note);
    if (signingKey != null) {
      assertParameter('onSign', onSign);
    }

    final fileSystem = FileSystem(fs);

    // TODO: Ensure normalizeAuthorObject and normalizeCommitterObject are correctly typed
    // and handle null inputs for _author and _committer gracefully.
    final authorDetails = await normalizeAuthorObject(
      fs: fileSystem,
      gitdir: effectiveGitdir,
      author: author,
    );
    if (authorDetails == null) throw MissingNameError('author');

    final committerDetails = await normalizeCommitterObject(
      fs: fileSystem,
      gitdir: effectiveGitdir,
      author: authorDetails, // Pass the normalized author
      committer: committer, // Pass original committer
    );
    if (committerDetails == null) throw MissingNameError('committer');

    return await addNoteInternal(
      fs: fileSystem, // Pass the FileSystem instance, not the raw fs client
      cache: effectiveCache,
      onSign: onSign,
      gitdir: effectiveGitdir,
      ref: ref,
      oid: oid,
      note: note is String
          ? Uint8List.fromList(note.codeUnits)
          : note as Uint8List,
      force: force ?? false,
      author: authorDetails,
      committer: committerDetails,
      signingKey: signingKey,
    );
  } catch (err) {
    // err.caller = 'git.addNote'; // JS specific
    print("Error in git.addNote: $err");
    rethrow;
  }
}
