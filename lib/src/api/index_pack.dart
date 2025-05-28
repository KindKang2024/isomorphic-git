import '../static_typedefs.dart';
import '../commands/index_pack.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Index a pack file
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [filepath] - The pack file path to index
///
/// Resolves successfully when the pack is indexed
Future<void> indexPack({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String filepath,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('filepath', filepath);
    gitdir ??= join(dir!, '.git');
    
    return await indexPackCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      filepath: filepath,
    );
  } catch (err) {
    rethrow;
  }
}