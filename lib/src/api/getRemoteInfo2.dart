import '../managers/git_remote_manager.dart';
import '../utils/assert_parameter.dart';
import '../utils/format_info_refs.dart'; // Assumed Dart equivalent
import '../typedefs.dart'; // For HttpClient, AuthCallbacks, and potentially ServerRef

// Assuming ServerRef structure. Adjust if your typedefs.dart defines it differently.
class ServerRef {
  final String ref;
  final String oid;
  final String? target;
  final String? peeled;

  ServerRef({required this.ref, required this.oid, this.target, this.peeled});

  Map<String, dynamic> toJson() => {
    'ref': ref,
    'oid': oid,
    if (target != null) 'target': target,
    if (peeled != null) 'peeled': peeled,
  };
}

class GetRemoteInfo2Result {
  final int protocolVersion; // 1 or 2
  final Map<String, dynamic>
  capabilities; // For v2, it's remote.capabilities2; for v1, it's parsed
  final List<ServerRef>? refs; // Only for protocolVersion 1

  GetRemoteInfo2Result({
    required this.protocolVersion,
    required this.capabilities,
    this.refs,
  }) {
    if (protocolVersion == 1 && refs == null) {
      // Or handle as an error, depending on strictness
      // throw ArgumentError('refs must be provided for protocolVersion 1');
    }
    if (protocolVersion == 2 && refs != null) {
      // Or handle as an error
      // throw ArgumentError('refs must not be provided for protocolVersion 2');
    }
  }

  Map<String, dynamic> toJson() => {
    'protocolVersion': protocolVersion,
    'capabilities': capabilities,
    if (refs != null) 'refs': refs!.map((r) => r.toJson()).toList(),
  };
}

Future<GetRemoteInfo2Result> getRemoteInfo2({
  required HttpClient http,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  String? corsProxy,
  required String url,
  Map<String, String> headers = const {},
  bool forPush = false,
  int protocolVersion = 2, // Default to 2, can be 1 or 2
}) async {
  try {
    assertParameter('http', http);
    assertParameter('url', url);
    if (protocolVersion != 1 && protocolVersion != 2) {
      throw ArgumentError('protocolVersion must be 1 or 2');
    }

    final remoteHelper = GitRemoteManager.getRemoteHelperFor(url: url);
    // Assuming the 'remote' object from discover will have properties like:
    // - protocolVersion (int)
    // - capabilities2 (Map<String, dynamic>) for v2
    // - capabilities (List<String> or Set<String>) for v1
    // - refs (Map<String, String>) for v1
    // - symrefs (Map<String, String>) for v1
    final remote = await remoteHelper.discover(
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

    if (remote.protocolVersion == 2) {
      return GetRemoteInfo2Result(
        protocolVersion: remote.protocolVersion as int,
        capabilities:
            remote.capabilities2 as Map<String, dynamic>? ??
            <String, dynamic>{},
      );
    } else {
      // Protocol version 1
      final Map<String, dynamic> v1Capabilities = {};
      // Assuming remote.capabilities for v1 is a List<String> or Set<String>
      final caps = remote.capabilities;
      if (caps is Iterable) {
        for (final capEntry in caps) {
          if (capEntry is String) {
            final parts = capEntry.split('=');
            if (parts.length > 1) {
              v1Capabilities[parts[0]] = parts[1];
            } else {
              v1Capabilities[parts[0]] = true;
            }
          }
        }
      }

      // Assuming formatInfoRefs exists and works with the 'remote' object structure
      // The JS `formatInfoRefs(remote, undefined, true, true)` implies `remote` is passed directly.
      // And it likely uses `remote.refs` and `remote.symrefs` internally.
      final List<ServerRef> serverRefs = formatInfoRefs(
        remote, // Pass the whole remote object as it might be expected by formatInfoRefs
        // The original JS passes `undefined, true, true`.
        // We need to know what these correspond to in the Dart version.
        // Assuming they are boolean flags, e.g., `includeTags: true, includeObjects: true`
        // For now, I'll make up some named parameters or pass nulls.
        // You will need to adjust this based on your `formatInfoRefs` signature.
        // option1: null,
        // option2: true,
        // option3: true
        // Placeholder: these arguments need to be confirmed for the Dart `formatInfoRefs`
      );

      return GetRemoteInfo2Result(
        protocolVersion: 1,
        capabilities: v1Capabilities,
        refs: serverRefs,
      );
    }
  } catch (err) {
    // err.caller = 'git.getRemoteInfo2'
    rethrow;
  }
}
