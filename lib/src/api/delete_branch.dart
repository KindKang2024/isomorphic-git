import '../static_typedefs.dart';
import '../commands/delete_branch.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Delete a local branch
///
/// Note: This only deletes loose branches - it should be fixed in the future to delete packed branches as well.
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [ref] - The branch to delete
///
/// Resolves successfully when filesystem operations are complete
Future<void> deleteBranch({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String ref,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    gitdir ??= join(dir!, '.git');
    
    return await deleteBranchCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      ref: ref,
    );
  } catch (err) {
    rethrow;
  }
}