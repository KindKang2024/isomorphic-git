import '../static_typedefs.dart';
import '../commands/find_root.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';

/// Find the root git directory
///
/// [fs] - a file system implementation
/// [filepath] - The file path to start searching from
///
/// Returns the root git directory path
Future<String> findRoot({
  required dynamic fs,
  required String filepath,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('filepath', filepath);
    
    return await findRootCommand(
      fs: FileSystem(fs),
      filepath: filepath,
    );
  } catch (err) {
    rethrow;
  }
}