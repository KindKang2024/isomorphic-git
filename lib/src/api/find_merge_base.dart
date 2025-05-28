import '../static_typedefs.dart';
import '../commands/find_merge_base.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Find the merge base between two commits
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [oids] - The commit oids to find the merge base for
///
/// Returns the merge base commit oids
Future<List<String>> findMergeBase({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required List<String> oids,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('oids', oids);
    gitdir ??= join(dir!, '.git');
    
    return await findMergeBaseCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      oids: oids,
    );
  } catch (err) {
    rethrow;
  }
}