import 'package:isomorphic_git/isomorphic_git.dart';
import '../commands/pull.dart' as _pull;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Like `pull`, but hard-coded with `fastForward: true` so there is no need for an `author` parameter.
///
/// Args:
///   fs: a file system client
///   http: an HTTP client
///   onProgress: optional progress event callback
///   onMessage: optional message event callback
///   onAuth: optional auth fill callback
///   onAuthFailure: optional auth rejected callback
///   onAuthSuccess: optional auth approved callback
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   ref: Which branch to merge into. By default this is the currently checked out branch.
///   url: (Added in 1.1.0) The URL of the remote repository. The default is the value set in the git config for that remote.
///   remote: (Added in 1.1.0) If URL is not specified, determines which remote to use.
///   remoteRef: (Added in 1.1.0) The name of the branch on the remote to fetch. By default this is the configured remote tracking branch.
///   corsProxy: Optional [CORS proxy](https://www.npmjs.com/%40isomorphic-git/cors-proxy). Overrides value in repo config.
///   singleBranch: Instead of the default behavior of fetching all the branches, only fetch a single branch.
///   headers: Additional headers to include in HTTP requests, similar to git's `extraHeader` config
///   cache: a [cache](cache.md) object
///
/// Returns:
///   Resolves successfully when pull operation completes
///
/// Example:
/// ```dart
/// await Git.fastForward(
///   fs: fs,
///   http: http,
///   dir: '/tutorial',
///   ref: 'main',
///   singleBranch: true,
/// );
/// print('done');
/// ```
Future<void> fastForward({
  required FsClient fs,
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
  String? corsProxy,
  bool? singleBranch,
  Map<String, String> headers = const {},
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('http', http);
    final effectiveGitdir = gitdir ?? join(dir, '.git');
    assertParameter('gitdir', effectiveGitdir);

    // This will not be used, but is required by the _pull command
    final thisWillNotBeUsed = _pull.Author(
      name: '',
      email: '',
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      timezoneOffset: 0,
    );

    return await _pull.pull(
      fs: FileSystem(fs),
      cache: cache,
      http: http,
      onProgress: onProgress,
      onMessage: onMessage,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      dir: dir,
      gitdir: effectiveGitdir,
      ref: ref,
      url: url,
      remote: remote,
      remoteRef: remoteRef,
      fastForwardOnly: true,
      corsProxy: corsProxy,
      singleBranch: singleBranch,
      headers: headers,
      author: thisWillNotBeUsed,
      committer: thisWillNotBeUsed,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.fastForward';
    rethrow;
  }
}
