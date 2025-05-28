import '../static_typedefs.dart';
import '../commands/writeTree.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Write a tree object directly
///
/// [fs] - a file system client
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [tree] - The tree object to write
///
/// Returns the SHA-1 object id of the newly written object
Future<String> writeTree({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required TreeObject tree,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('tree', tree);
    gitdir ??= join(dir!, '.git');
    
    return await writeTreeCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      tree: tree,
    );
  } catch (err) {
    rethrow;
  }
}