import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// List refs
Future<List<String>> listRefs({
  required FileSystem fs,
  String? dir,
  String? gitdir,
  required String filepath,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    return GitRefManager.listRefs(
      fs: FileSystem(fs.client),
      gitdir: gitdir,
      filepath: filepath,
    );
  } catch (err) {
    //TODO: err.caller = 'git.listRefs';
    rethrow;
  }
}
