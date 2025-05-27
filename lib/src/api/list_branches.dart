import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// List branches
///
/// By default it lists local branches. If a 'remote' is specified, it lists the remote's branches.
/// When listing remote branches, the HEAD branch is not filtered out, so it may be included in the list of results.
///
/// Note that specifying a remote does not actually contact the server and update the list of branches.
/// If you want an up-to-date list, first do a `fetch` to that remote.
/// (Which branch you fetch doesn't matter - the list of branches available on the remote is updated during the fetch handshake.)
///
/// Also note, that a branch is a reference to a commit. If you initialize a new repository it has no commits, so the
/// `listBranches` function will return an empty list, until you create the first commit.
///
Future<List<String>> listBranches({
  required FileSystem fs,
  String? dir,
  String? gitdir,
  String? remote,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);

    return GitRefManager.listBranches(
      fs: FileSystem(fs.client),
      gitdir: gitdir,
      remote: remote,
    );
  } catch (err) {
    //TODO: err.caller = 'git.listBranches';
    rethrow;
  }
}
