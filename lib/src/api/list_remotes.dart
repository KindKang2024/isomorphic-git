import '../commands/list_remotes.dart' as commands;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

class RemoteEntry {
  final String remote;
  final String url;

  RemoteEntry({required this.remote, required this.url});
}

/// List remotes
Future<List<RemoteEntry>> listRemotes({
  required FileSystem fs,
  String? dir,
  String? gitdir,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);

    var results = await commands.listRemotes(
      fs: FileSystem(fs.client),
      gitdir: gitdir,
    );
    return results
        .map((e) => RemoteEntry(remote: e['remote'], url: e['url']))
        .toList();
  } catch (err) {
    //TODO: err.caller = 'git.listRemotes';
    rethrow;
  }
}
