import '../managers/git_ignore_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // For FsClient

Future<bool> isIgnored({
  required FsClient fs,
  required String dir,
  String? gitdir,
  required String filepath,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('dir', dir);
    final gd = gitdir ?? join(dir, '.git');
    assertParameter('gitdir', gd);
    assertParameter('filepath', filepath);

    // Assuming GitIgnoreManager.isIgnored is a static method or you have an instance
    // The JS code calls it statically: GitIgnoreManager.isIgnored(...)
    // So, the Dart equivalent should also be a static method.
    return await GitIgnoreManager.isIgnored(
      fs: FileSystem(fs),
      dir: dir,
      gitdir: gd,
      filepath: filepath,
    );
  } catch (err) {
    // err.caller = 'git.isIgnored'
    rethrow;
  }
}
