import '../static_typedefs.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Expand an abbreviated ref to its full name
///
/// [fs] - a file system implementation
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [ref] - The ref to expand
///
/// Returns the expanded ref name
Future<String> expandRef({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String ref,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    gitdir ??= join(dir!, '.git');
    
    return await GitRefManager.expand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      ref: ref,
    );
  } catch (err) {
    rethrow;
  }
}