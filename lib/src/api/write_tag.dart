import '../static_typedefs.dart';
import '../commands/writeTag.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Write a tag object directly
///
/// [fs] - a file system client
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [tag] - The tag object to write
///
/// Returns the SHA-1 object id of the newly written object
Future<String> writeTag({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required TagObject tag,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('tag', tag);
    gitdir ??= join(dir!, '.git');
    
    return await writeTagCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      tag: tag,
    );
  } catch (err) {
    rethrow;
  }
}