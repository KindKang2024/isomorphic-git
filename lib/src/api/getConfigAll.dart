import '../commands/get_config_all.dart' as commands_get_config_all;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // Assuming FsClient is defined here

Future<List<dynamic>> getConfigAll({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String path,
}) async {
  try {
    assertParameter('fs', fs);
    final gd = gitdir ?? (dir != null ? join(dir, '.git') : null);
    assertParameter('gitdir', gd);
    assertParameter('path', path);

    return await commands_get_config_all.getConfigAll(
      fs: FileSystem(fs),
      gitdir: gd!,
      path: path,
    );
  } catch (err) {
    // Consider custom exception for err.caller
    rethrow;
  }
}
