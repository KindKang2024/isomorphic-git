import '../static_typedefs.dart';
import '../commands/fast_forward.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Fast-forward a branch
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [ref] - The branch to fast-forward
/// [oid] - The commit to fast-forward to
///
/// Resolves successfully when the fast-forward is complete
Future<void> fastForward({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String ref,
  required String oid,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    assertParameter('oid', oid);
    gitdir ??= join(dir!, '.git');
    
    return await fastForwardCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      ref: ref,
      oid: oid,
    );
  } catch (err) {
    rethrow;
  }
}