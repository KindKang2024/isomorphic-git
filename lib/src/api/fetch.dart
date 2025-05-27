import '../commands/fetch.dart' as commands_fetch;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart';

class FetchResult {
  final String? defaultBranch;
  final String? fetchHead;
  final String? fetchHeadDescription;
  final Map<String, String>? headers;
  final List<String>? pruned;

  FetchResult({
    this.defaultBranch,
    this.fetchHead,
    this.fetchHeadDescription,
    this.headers,
    this.pruned,
  });
}

Future<FetchResult> fetch({
  required FsClient fs,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthFailureCallback? onAuthFailure,
  AuthSuccessCallback? onAuthSuccess,
  String? dir,
  String? gitdir,
  String? url,
  String? remote,
  bool singleBranch = false,
  String? ref,
  String? remoteRef,
  bool tags = false,
  int? depth,
  bool relative = false,
  DateTime? since,
  List<String> exclude = const [],
  bool prune = false,
  bool pruneTags = false,
  String? corsProxy,
  Map<String, String> headers = const {},
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('http', http);

    final gd = gitdir ?? (dir != null ? join(dir, '.git') : null);
    assertParameter('gitdir', gd);

    return await commands_fetch.fetch(
      fs: FileSystem(fs),
      cache: cache,
      http: http,
      onProgress: onProgress,
      onMessage: onMessage,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      gitdir: gd!,
      ref: ref,
      remote: remote,
      remoteRef: remoteRef,
      url: url,
      corsProxy: corsProxy,
      depth: depth,
      since: since,
      exclude: exclude,
      relative: relative,
      tags: tags,
      singleBranch: singleBranch,
      headers: headers,
      prune: prune,
      pruneTags: pruneTags,
    );
  } catch (err) {
    // In Dart, it's common to rethrow the error or a more specific error.
    // For now, let's just rethrow. Consider how to handle err.caller in Dart.
    // One option is to create a custom exception class.
    rethrow;
  }
}

// Define the callback types if they are not already defined elsewhere
// For example:
// typedef ProgressCallback = void Function(ProgressEvent event);
// typedef MessageCallback = void Function(String message);
// typedef AuthCallback = Future<dynamic> Function();
// typedef AuthFailureCallback = Future<dynamic> Function(dynamic auth);
// typedef AuthSuccessCallback = Future<void> Function(dynamic auth);

// HttpClient and FsClient would be defined elsewhere, e.g.:
// abstract class HttpClient { ... }
// abstract class FsClient { ... }

// ProgressEvent would also be defined elsewhere:
// class ProgressEvent { ... }

// Note: The `typedefs.js` import suggests these types might be complex.
// For now, I'm using simple typedefs as placeholders.
// You'll need to ensure these match the actual definitions.
