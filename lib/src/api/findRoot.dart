import '../commands/find_root.dart' as commands_find_root;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../typedefs.dart'; // Assuming FsClient is defined here
// Assuming NotFoundError is defined in a custom errors file or similar
// import '../errors/not_found_error.dart';

Future<String> findRoot({
  required FsClient fs,
  required String filepath,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('filepath', filepath);

    return await commands_find_root.findRoot(
      fs: FileSystem(fs),
      filepath: filepath,
    );
  } catch (err) {
    // In Dart, you might want to catch specific error types if _findRoot can throw them.
    // For instance, if _findRoot throws a specific NotFoundError, catch it and rethrow.
    // if (err is NotFoundError) { ... }
    // For now, just rethrowing. The err.caller assignment is not directly translatable
    // unless you have a custom error hierarchy that supports a 'caller' property.
    rethrow;
  }
}
