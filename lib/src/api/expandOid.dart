import '../models/file_system.dart';
import '../storage/expand_oid.dart' as _expand_oid;
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import 'package:isomorphic_git/isomorphic_git.dart';

/// Expand and resolve a short oid into a full oid
///
/// Args:
///   fs: a file system implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   oid: The shortened oid prefix to expand (like "0414d2a")
///   cache: a [cache](cache.md) object
///
/// Returns:
///   Resolves successfully with the full oid (like "0414d2a286d7bbc7a4a326a61c1f9f888a8ab87f")
///
/// Example:
/// ```dart
/// String oid = await Git.expandOid(fs: fs, dir: '/tutorial', oid: '0414d2a');
/// print(oid);
/// ```
Future<String> expandOid({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String oid,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);
    return await _expand_oid.expandOid(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: effectiveGitdir,
      oid: oid,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.expandOid';
    rethrow;
  }
}
