import '../static_typedefs.dart';
import '../commands/get_config_all.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Get all git config values for a path
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [path] - The config path to get all values for
///
/// Returns all config values for the path
Future<List<dynamic>> getConfigAll({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String path,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('path', path);
    gitdir ??= join(dir!, '.git');
    
    return await getConfigAllCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      path: path,
    );
  } catch (err) {
    rethrow;
  }
}