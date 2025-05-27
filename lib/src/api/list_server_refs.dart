import '../managers/git_remote_http.dart';
import '../utils/assert_parameter.dart';
import '../utils/format_info_refs.dart';
import '../wire/parse_list_refs_response.dart';
import '../wire/write_list_refs_request.dart';
import '../models/http_client.dart'; // Assuming HttpClient is defined here
import '../typedefs.dart'; // Assuming ServerRef is defined here

/// Fetch a list of refs (branches, tags, etc) from a server.
Future<List<ServerRef>> listServerRefs({
  required HttpClient http,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  required String url,
  String? corsProxy,
  bool forPush = false,
  Map<String, String> headers = const {},
  int protocolVersion = 2,
  String? prefix,
  bool symrefs = false,
  bool peelTags = false,
}) async {
  try {
    assertParameter('http', http);
    assertParameter('url', url);

    final remote = await GitRemoteHTTP.discover(
      http: http,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      corsProxy: corsProxy,
      service: forPush ? 'git-receive-pack' : 'git-upload-pack',
      url: url,
      headers: headers,
      protocolVersion: protocolVersion,
    );

    if (remote.protocolVersion == 1) {
      return formatInfoRefs(remote, prefix, symrefs, peelTags);
    }

    // Protocol Version 2
    final body = await writeListRefsRequest(
      prefix: prefix,
      symrefs: symrefs,
      peelTags: peelTags,
    );

    final res = await GitRemoteHTTP.connect(
      http: http,
      auth: remote.auth,
      headers: headers,
      corsProxy: corsProxy,
      service: forPush ? 'git-receive-pack' : 'git-upload-pack',
      url: url,
      body: body,
    );

    // Assuming res.body is a Stream<List<int>> and parseListRefsResponse handles it
    return parseListRefsResponse(res.body);
  } catch (err) {
    //TODO: err.caller = 'git.listServerRefs';
    rethrow;
  }
}
