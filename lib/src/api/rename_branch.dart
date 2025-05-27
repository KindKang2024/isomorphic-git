import '../commands/rename_branch.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Rename a branch
///
/// [fs] - a file system implementation
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [ref] - What to name the branch
/// [oldref] - What the name of the branch was
/// [checkout] - Update `HEAD` to point at the newly created branch
///
/// Returns a [Future<void>] that resolves successfully when filesystem operations are complete.
///
/// Example:
/// ```dart
/// await git.renameBranch(fs: fs, dir: '/tutorial', ref: 'main', oldref: 'master');
/// print('done');
/// ```
Future<void> renameBranch({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String ref,
  required String oldref,
  bool checkout = false,
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('ref', ref);
    assertParameter('oldref', oldref);

    return await _renameBranch(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      ref: ref,
      oldref: oldref,
      checkout: checkout,
    );
  } catch (e) {
    rethrow;
  }
}
