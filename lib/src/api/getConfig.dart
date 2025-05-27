import '../commands/get_config.dart' as commands_get_config;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // Assuming FsClient is defined here

Future<dynamic> getConfig({
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

    return await commands_get_config.getConfig(
      fs: FileSystem(fs),
      gitdir: gd!,
      path: path,
    );
  } catch (err) {
    // Consider custom exception for err.caller
    rethrow;
  }
}
