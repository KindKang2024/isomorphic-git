import '../static_typedefs.dart';
import '../commands/delete_remote.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Delete a remote
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [remote] - The name of the remote to delete
///
/// Resolves successfully when filesystem operations are complete
Future<void> deleteRemote({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String remote,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('remote', remote);
    gitdir ??= join(dir!, '.git');
    
    return await deleteRemoteCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      remote: remote,
    );
  } catch (err) {
    rethrow;
  }
}