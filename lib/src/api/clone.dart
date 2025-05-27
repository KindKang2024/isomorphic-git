import 'package:isomorphic_git/isomorphic_git.dart';
import '../commands/clone.dart' as _clone;
import 'package:./models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Clone a repository
///
/// Args:
///   fs: a file system implementation
///   http: an HTTP client
///   onProgress: optional progress event callback
///   onMessage: optional message event callback
///   onAuth: optional auth fill callback
///   onAuthFailure: optional auth rejected callback
///   onAuthSuccess: optional auth approved callback
///   onPostCheckout: optional post-checkout hook callback
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   url: The URL of the remote repository
///   corsProxy: Optional [CORS proxy](https://www.npmjs.com/%40isomorphic-git/cors-proxy). Value is stored in the git config file for that repo.
///   ref: Which branch to checkout. By default this is the designated "main branch" of the repository.
///   singleBranch: Instead of the default behavior of fetching all the branches, only fetch a single branch.
///   noCheckout: If true, clone will only fetch the repo, not check out a branch. Skipping checkout can save a lot of time normally spent writing files to disk.
///   noTags: By default clone will fetch all tags. `noTags` disables that behavior.
///   remote: What to name the remote that is created.
///   depth: Integer. Determines how much of the git repository's history to retrieve
///   since: Only fetch commits created after the given date. Mutually exclusive with `depth`.
///   exclude: A list of branches or tags. Instructs the remote server not to send us any commits reachable from these refs.
///   relative: Changes the meaning of `depth` to be measured from the current shallow depth rather than from the branch tip.
///   headers: Additional headers to include in HTTP requests, similar to git's `extraHeader` config
///   cache: a [cache](cache.md) object
///
/// Returns:
///   Resolves successfully when clone completes
///
/// Example:
/// ```dart
/// await Git.clone(
///   fs: fs,
///   http: http,
///   dir: '/tutorial',
///   corsProxy: 'https://cors.isomorphic-git.org',
///   url: 'https://github.com/isomorphic-git/isomorphic-git',
///   singleBranch: true,
///   depth: 1,
/// );
/// print('done');
/// ```
Future<void> clone({
  required FsClient fs,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  PostCheckoutCallback? onPostCheckout,
  required String dir,
  String? gitdir,
  required String url,
  String? corsProxy,
  String? ref,
  String remote = 'origin',
  int? depth,
  DateTime? since,
  List<String> exclude = const [],
  bool relative = false,
  bool singleBranch = false,
  bool noCheckout = false,
  bool noTags = false,
  Map<String, String> headers = const {},
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('http', http);
    final effectiveGitdir = gitdir ?? join(dir, '.git');
    assertParameter('gitdir', effectiveGitdir);
    if (!noCheckout) {
      assertParameter('dir', dir);
    }
    assertParameter('url', url);

    return await _clone.clone(
      fs: FileSystem(fs),
      cache: cache,
      http: http,
      onProgress: onProgress,
      onMessage: onMessage,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      onPostCheckout: onPostCheckout,
      dir: dir,
      gitdir: effectiveGitdir,
      url: url,
      corsProxy: corsProxy,
      ref: ref,
      remote: remote,
      depth: depth,
      since: since,
      exclude: exclude,
      relative: relative,
      singleBranch: singleBranch,
      noCheckout: noCheckout,
      noTags: noTags,
      headers: headers,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.clone';
    rethrow;
  }
}
