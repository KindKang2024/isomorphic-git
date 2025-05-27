import '../commands/delete_remote.dart' as _delete_remote;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Removes the local config entry for a given remote
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   remote: The name of the remote to delete
///
/// Returns:
///   Resolves successfully when filesystem operations are complete
///
/// Example:
/// ```dart
/// await Git.deleteRemote(fs: fs, dir: '/tutorial', remote: 'upstream');
/// print('done');
/// ```
Future<void> deleteRemote({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String remote,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('remote', remote);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');

    return await _delete_remote.deleteRemote(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      remote: remote,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.deleteRemote';
    rethrow;
  }
}
