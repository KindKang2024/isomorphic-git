import '../static_typedefs.dart';
import '../commands/writeCommit.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Write a commit object directly
///
/// [fs] - a file system client
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [commit] - The commit object to write
///
/// Returns the SHA-1 object id of the newly written object
Future<String> writeCommit({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required CommitObject commit,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('commit', commit);
    gitdir ??= join(dir!, '.git');
    assertParameter('gitdir', gitdir);
    
    return await writeCommitCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      commit: commit,
    );
  } catch (err) {
    rethrow;
  }
}