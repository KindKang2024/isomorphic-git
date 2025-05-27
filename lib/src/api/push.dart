import '../commands/push.dart' as commands;
import '../models/file_system.dart';
import '../models/http_client.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // Assuming ProgressCallback, MessageCallback, AuthCallback, PrePushCallback, PushResult are defined here

/// Push a branch or tag
Future<PushResult> push({
  required FileSystem fs,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  PrePushCallback? onPrePush,
  String? dir,
  String? gitdir,
  String? ref,
  String? remoteRef,
  String remote = 'origin',
  String? url,
  bool force = false,
  bool delete = false,
  String? corsProxy,
  Map<String, String> headers = const {},
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('http', http);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);

    var result = await commands.push(
      fs: FileSystem(fs.client),
      cache: cache,
      http: http,
      onProgress: onProgress,
      onMessage: onMessage,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      onPrePush: onPrePush,
      gitdir: gitdir,
      ref: ref,
      remoteRef: remoteRef,
      remote: remote,
      url: url,
      force: force,
      delete: delete,
      corsProxy: corsProxy,
      headers: headers,
    );
    // Assuming PushResult has a fromMap constructor or similar
    // If PushResult is a complex type, this might need adjustment
    return PushResult.fromMap(result as Map<String, dynamic>);
  } catch (err) {
    //TODO: err.caller = 'git.push';
    rethrow;
  }
}
