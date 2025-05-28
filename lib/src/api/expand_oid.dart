import '../static_typedefs.dart';
import '../models/file_system.dart';
import '../storage/expand_oid.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Expand and resolve a short oid into a full oid
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [oid] - The shortened oid prefix to expand (like "0414d2a")
/// [cache] - a cache object
///
/// Returns the full oid (like "0414d2a286d7bbc7a4a326a61c1f9f888a8ab87f")
Future<String> expandOid({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String oid,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('oid', oid);
    gitdir ??= join(dir!, '.git');
    assertParameter('gitdir', gitdir);
    
    return await expandOidStorage(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: gitdir,
      oid: oid,
    );
  } catch (err) {
    rethrow;
  }
}