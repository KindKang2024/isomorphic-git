import '../commands/pull.dart' as commands;
import '../errors/missing_name_error.dart';
import '../models/file_system.dart';
import '../models/http_client.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/normalize_author_object.dart';
import '../utils/normalize_committer_object.dart';
import '../typedefs.dart'; // Assuming ProgressCallback, MessageCallback, AuthCallback, etc. are defined here

/// Fetch and merge commits from a remote repository
Future<void> pull({
  required FileSystem fs,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  required String dir,
  String? gitdir,
  String? ref,
  String? url,
  String? remote,
  String? remoteRef,
  bool prune = false,
  bool pruneTags = false,
  bool fastForward = true,
  bool fastForwardOnly = false,
  String? corsProxy,
  bool? singleBranch,
  Map<String, String> headers = const {},
  Author? authorInput,
  Committer? committerInput,
  String? signingKey,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);

    final author = await normalizeAuthorObject(
      fs: fs,
      gitdir: gitdir,
      author: authorInput,
    );
    if (author == null) throw MissingNameError('author');

    final committer = await normalizeCommitterObject(
      fs: fs,
      gitdir: gitdir,
      author: author,
      committer: committerInput,
    );
    if (committer == null) throw MissingNameError('committer');

    return await commands.pull(
      fs: FileSystem(fs.client),
      cache: cache,
      http: http,
      onProgress: onProgress,
      onMessage: onMessage,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      dir: dir,
      gitdir: gitdir,
      ref: ref,
      url: url,
      remote: remote,
      remoteRef: remoteRef,
      fastForward: fastForward,
      fastForwardOnly: fastForwardOnly,
      corsProxy: corsProxy,
      singleBranch: singleBranch,
      headers: headers,
      author: author,
      committer: committer,
      signingKey: signingKey,
      prune: prune,
      pruneTags: pruneTags,
    );
  } catch (err) {
    //TODO: err.caller = 'git.pull';
    rethrow;
  }
}
