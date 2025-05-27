import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Delete a local ref
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   ref: The ref to delete
///
/// Returns:
///   Resolves successfully when filesystem operations are complete
///
/// Example:
/// ```dart
/// await Git.deleteRef(fs: fs, dir: '/tutorial', ref: 'refs/tags/test-tag');
/// print('done');
/// ```
Future<void> deleteRef({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String ref,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');

    await GitRefManager.deleteRef(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      ref: ref,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.deleteRef';
    rethrow;
  }
}
