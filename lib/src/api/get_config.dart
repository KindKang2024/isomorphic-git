import '../static_typedefs.dart';
import '../commands/get_config.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Get a git config value
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [path] - The config path to get
///
/// Returns the config value
Future<dynamic> getConfig({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String path,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('path', path);
    gitdir ??= join(dir!, '.git');
    
    return await getConfigCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      path: path,
    );
  } catch (err) {
    rethrow;
  }
}