import '../commands/remove_note.dart';
import '../errors/missing_name_error.dart';
import '../models/file_system.dart';
import '../models/author.dart'; // Assuming an Author model
import '../models/committer.dart'; // Assuming a Committer model
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/normalize_author_object.dart';
import '../utils/normalize_committer_object.dart';

// typedef SignCallback = Future<String> Function(String payload);
// In Dart, a function type: typedef SignCallback = Future<String> Function({String payload});
// Or more simply if it's just one string: typedef SignCallback = Future<String> Function(String);
// For now, I'll use Function as type for onSign for flexibility, needs specific definition based on usage

/// Remove an object note
///
/// [fs] - a file system client
/// [onSign] - a PGP signing implementation
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [ref] - The notes ref to look under
/// [oid] - The SHA-1 object id of the object to remove the note from.
/// [author] - The details about the author.
/// [committer] - The details about the note committer.
/// [signingKey] - Sign the tag object using this private PGP key.
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<String>] that resolves successfully with the SHA-1 object id of the commit object for the note removal.
Future<String> removeNote({
  required dynamic fs,
  Function? onSign,
  String? dir,
  String? gitdir,
  String ref = 'refs/notes/commits',
  required String oid,
  Author? authorInput, // Using Author class directly
  Committer? committerInput, // Using Committer class directly
  String? signingKey,
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');
  final fsModel = FileSystem(fs);

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);

    final author = await normalizeAuthorObject(
      fs: fsModel,
      gitdir: effectiveGitdir,
      author: authorInput,
    );
    if (author == null) throw MissingNameError('author');

    final committer = await normalizeCommitterObject(
      fs: fsModel,
      gitdir: effectiveGitdir,
      author: author, // normalized author
      committer: committerInput,
    );
    if (committer == null) throw MissingNameError('committer');

    return await _removeNote(
      fs: fsModel,
      cache: cache,
      onSign: onSign,
      gitdir: effectiveGitdir,
      ref: ref,
      oid: oid,
      author: author,
      committer: committer,
      signingKey: signingKey,
    );
  } catch (e) {
    rethrow;
  }
}
