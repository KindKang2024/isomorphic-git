import '../commands/is_descendent.dart' as commands_is_descendent;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // For FsClient

Future<bool> isDescendent({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String oid,
  required String ancestor,
  int depth = -1,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    final gd = gitdir ?? (dir != null ? join(dir, '.git') : null);
    assertParameter('gitdir', gd);
    assertParameter('oid', oid);
    assertParameter('ancestor', ancestor);

    return await commands_is_descendent.isDescendent(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: gd!,
      oid: oid,
      ancestor: ancestor,
      depth: depth,
    );
  } catch (err) {
    // err.caller = 'git.isDescendent'
    rethrow;
  }
}
