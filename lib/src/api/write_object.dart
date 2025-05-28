import '../static_typedefs.dart';
import '../commands/write_object.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Write an object directly
///
/// [fs] - a file system client
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [type] - The object type
/// [object] - The object content to write
///
/// Returns the SHA-1 object id of the newly written object
Future<String> writeObject({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String type,
  required dynamic object,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('type', type);
    assertParameter('object', object);
    gitdir ??= join(dir!, '.git');
    
    return await writeObjectCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      type: type,
      object: object,
    );
  } catch (err) {
    rethrow;
  }
}