import '../static_typedefs.dart';
import '../commands/write_ref.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Write a ref
///
/// [fs] - a file system client
/// [dir] - The working tree directory path
/// [gitdir] - The git directory path (defaults to join(dir,'.git'))
/// [ref] - The ref name to write
/// [value] - The ref value to write
///
/// Resolves successfully when the ref is written
Future<void> writeRef({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String ref,
  required String value,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('ref', ref);
    assertParameter('value', value);
    gitdir ??= join(dir!, '.git');
    
    return await writeRefCommand(
      fs: FileSystem(fs),
      gitdir: gitdir,
      ref: ref,
      value: value,
    );
  } catch (err) {
    rethrow;
  }
}