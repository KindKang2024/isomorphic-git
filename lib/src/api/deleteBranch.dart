import '../commands/delete_branch.dart' as _delete_branch;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Delete a local branch
///
/// > Note: This only deletes loose branches - it should be fixed in the future to delete packed branches as well.
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   ref: The branch to delete
///
/// Returns:
///   Resolves successfully when filesystem operations are complete
///
/// Example:
/// ```dart
/// await Git.deleteBranch(fs: fs, dir: '/tutorial', ref: 'local-branch');
/// print('done');
/// ```
Future<void> deleteBranch({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String ref,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');

    return await _delete_branch.deleteBranch(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      ref: ref,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.deleteBranch';
    rethrow;
  }
}
