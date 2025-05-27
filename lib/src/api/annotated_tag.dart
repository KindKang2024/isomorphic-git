// import '../typedefs.dart'; // Dart handles types and callbacks

import '../commands/annotated_tag.dart'
    show annotatedTagInternal; // Assuming _annotatedTag is annotatedTagInternal
import '../errors/missing_name_error.dart';
import '../models/file_system.dart'; // Assumes FsClient is here
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/normalize_author_object.dart'; // Assuming this can be used for tagger

// Define a type for the onSign callback if it's complex
// typedef SignCallback = Future<String> Function(String dataToSign);

// Define Tagger data class (similar to PersonDetails for author/committer)
// class TaggerDetails {
//   String? name;
//   String? email;
//   int? timestamp;
//   int? timezoneOffset;
//   TaggerDetails({this.name, this.email, this.timestamp, this.timezoneOffset});
// }

/// Create an annotated tag.
Future<void> annotatedTag({
  required dynamic fs, // Should be FsClient
  dynamic onSign, // Should be SignCallback?
  String? dir,
  String? gitdir,
  required String ref,
  String? message,
  String object = 'HEAD',
  dynamic tagger, // Should be TaggerDetails?
  String? gpgsig,
  String? signingKey,
  bool force = false,
  Map<String, dynamic>? cache,
}) async {
  final effectiveGitdir = gitdir ?? (dir != null ? join(dir, '.git') : null);
  final effectiveCache = cache ?? {};
  final effectiveMessage = message ?? ref;

  if (effectiveGitdir == null) {
    throw ArgumentError('Either dir or gitdir must be provided.');
  }

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('ref', ref);
    if (signingKey != null) {
      assertParameter('onSign', onSign);
    }
    if (signingKey != null && gpgsig != null) {
      throw ArgumentError('Cannot use both signingKey and gpgsig options.');
    }

    final fileSystem = FileSystem(fs);

    // Fill in missing arguments with default values
    // TODO: Ensure normalizeAuthorObject is suitable for tagger or create normalizeTaggerObject
    final taggerDetails = await normalizeAuthorObject(
      fs: fileSystem,
      gitdir: effectiveGitdir,
      author: tagger,
    );
    if (taggerDetails == null) throw MissingNameError('tagger');

    await annotatedTagInternal(
      fs: fileSystem, // Pass FileSystem instance
      cache: effectiveCache,
      onSign: onSign,
      gitdir: effectiveGitdir,
      ref: ref,
      tagger: taggerDetails,
      message: effectiveMessage,
      gpgsig: gpgsig,
      object: object,
      signingKey: signingKey,
      force: force,
    );
  } catch (err) {
    // err.caller = 'git.annotatedTag'; // JS specific
    print("Error in git.annotatedTag: $err");
    rethrow;
  }
}
