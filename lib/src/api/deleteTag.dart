import '../commands/delete_tag.dart' as _delete_tag;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Delete a local tag ref
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   ref: The tag to delete
///
/// Returns:
///   Resolves successfully when filesystem operations are complete
///
/// Example:
/// ```dart
/// await Git.deleteTag(fs: fs, dir: '/tutorial', ref: 'test-tag');
/// print('done');
/// ```
Future<void> deleteTag({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String ref,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');

    return await _delete_tag.deleteTag(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      ref: ref,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.deleteTag';
    rethrow;
  }
}
