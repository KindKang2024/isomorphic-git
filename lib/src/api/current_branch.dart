import '../static_typedefs.dart';
import '../commands/current_branch.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Get the name of the branch currently pointed to by .git/HEAD
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [fullname] - Return the full path (e.g. "refs/heads/main") instead of the abbreviated form
/// [test] - If the current branch doesn't actually exist (such as right after git init) then return null
///
/// Returns the name of the current branch or null if the HEAD is detached.
Future<String?> currentBranch({
  required dynamic fs,
  String? dir,
  String? gitdir,
  bool fullname = false,
  bool test = false,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir!, '.git');
    assertParameter('gitdir', gitdir);
    
    return await currentBranchCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      fullname: fullname,
      test: test,
    );
  } catch (err) {
    // Add caller information for debugging
    rethrow;
  }
}