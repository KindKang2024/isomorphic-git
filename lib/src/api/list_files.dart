import '../commands/list_files.dart' as commands;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// List all the files in the git index or a commit
///
/// > Note: This function is efficient for listing the files in the staging area,
/// > but listing all the files in a commit requires recursively walking through the git object store.
/// > If you do not require a complete list of every file, better performance can be achieved by using
/// > [walk](./walk) and ignoring subdirectories you don't care about.
///
Future<List<String>> listFiles({
  required FileSystem fs,
  String? dir,
  String? gitdir,
  String? ref,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);

    return await commands.listFiles(
      fs: FileSystem(fs.client),
      cache: cache,
      gitdir: gitdir,
      ref: ref,
    );
  } catch (err) {
    //TODO: err.caller = 'git.listFiles';
    rethrow;
  }
}
