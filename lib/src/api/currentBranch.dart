import '../commands/current_branch.dart' as _current_branch;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Get the name of the branch currently pointed to by .git/HEAD
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   fullname: Return the full path (e.g. "refs/heads/main") instead of the abbreviated form.
///   test: If the current branch doesn't actually exist (such as right after git init) then return `null`.
///
/// Returns:
///   The name of the current branch or null if the HEAD is detached.
///
/// Example:
/// ```dart
/// // Get the current branch name
/// String? branch = await Git.currentBranch(
///   fs: fs,
///   dir: '/tutorial',
///   fullname: false,
/// );
/// print(branch);
/// ```
Future<String?> currentBranch({
  required FsClient fs,
  String? dir,
  String? gitdir,
  bool fullname = false,
  bool test = false,
}) async {
  try {
    assertParameter('fs', fs);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');
    assertParameter('gitdir', effectiveGitdir);
    return await _current_branch.currentBranch(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      fullname: fullname,
      test: test,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.currentBranch';
    rethrow;
  }
}
