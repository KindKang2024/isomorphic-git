import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Get the value of a symbolic ref or resolve a ref to its SHA-1 object id
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [ref] - The ref to resolve
/// [depth] - How many symbolic references to follow before returning
///
/// Returns a [Future<String>] that resolves successfully with a SHA-1 object id or the value of a symbolic ref.
///
/// Example:
/// ```dart
/// String currentCommit = await git.resolveRef(fs: fs, dir: '/tutorial', ref: 'HEAD');
/// print(currentCommit);
/// String currentBranch = await git.resolveRef(fs: fs, dir: '/tutorial', ref: 'HEAD', depth: 2);
/// print(currentBranch);
/// ```
Future<String> resolveRef({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String ref,
  int? depth,
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('ref', ref);

    final String oid = await GitRefManager.resolve(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      ref: ref,
      depth: depth,
    );
    return oid;
  } catch (e) {
    rethrow;
  }
}
