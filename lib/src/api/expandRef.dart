import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Expand an abbreviated ref to its full name
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   ref: The ref to expand (like "v1.0.0")
///
/// Returns:
///   Resolves successfully with a full ref name ("refs/tags/v1.0.0")
///
/// Example:
/// ```dart
/// String fullRef = await Git.expandRef(fs: fs, dir: '/tutorial', ref: 'main');
/// print(fullRef);
/// ```
Future<String> expandRef({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String ref,
}) async {
  try {
    assertParameter('fs', fs);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('ref', ref);
    return await GitRefManager.expand(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      ref: ref,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.expandRef';
    rethrow;
  }
}
