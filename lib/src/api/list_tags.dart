import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// List tags
Future<List<String>> listTags({
  required FileSystem fs,
  String? dir,
  String? gitdir,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    return GitRefManager.listTags(fs: FileSystem(fs.client), gitdir: gitdir);
  } catch (err) {
    //TODO: err.caller = 'git.listTags';
    rethrow;
  }
}
