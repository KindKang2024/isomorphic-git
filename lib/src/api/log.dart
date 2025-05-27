import '../commands/log.dart' as commands;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // Assuming ReadCommitResult is defined here

/// Get commit descriptions from the git history
Future<List<ReadCommitResult>> log({
  required FileSystem fs,
  String? dir,
  String? gitdir,
  String? filepath,
  String ref = 'HEAD',
  int? depth,
  DateTime? since,
  bool force = false,
  bool follow = false,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('ref', ref);

    return await commands.log(
      fs: FileSystem(fs.client),
      cache: cache,
      gitdir: gitdir,
      filepath: filepath,
      ref: ref,
      depth: depth,
      since: since,
      force: force,
      follow: follow,
    );
  } catch (err) {
    //TODO: err.caller = 'git.log';
    rethrow;
  }
}
