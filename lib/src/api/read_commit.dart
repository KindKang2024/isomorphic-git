import '../commands/read_commit.dart';
import '../models/file_system.dart';
import '../models/commit_object.dart'; // Assuming you have this model
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

// Assuming ReadCommitResult is similar to CommitObject or a wrapper
// For now, let's use CommitObject directly as the return type or define ReadCommitResult
// For simplicity, I'll assume _readCommit returns a CommitObject directly or a type that can be cast to it.

/// Read a commit object directly
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [oid] - The SHA-1 object id to get. Annotated tags are peeled.
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<CommitObject>] that resolves successfully with a git commit object.
/// See [CommitObject]
///
/// Example:
/// ```dart
/// // Read a commit object
/// String sha = await git.resolveRef(fs: fs, dir: '/tutorial', ref: 'main');
/// print(sha);
/// CommitObject commit = await git.readCommit(fs: fs, dir: '/tutorial', oid: sha);
/// print(commit);
/// ```
Future<CommitObject> readCommit({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String oid,
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);

    // Assuming _readCommit is adapted to Dart and FileSystem constructor is as well
    // And that _readCommit returns a Future<CommitObject> or similar compatible type.
    return await _readCommit(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: effectiveGitdir,
      oid: oid,
    );
  } catch (e) {
    // In Dart, it's more common to rethrow the original error or a new error that wraps it.
    rethrow;
  }
}
