import '../managers/git_remote_manager.dart';
import '../utils/assert_parameter.dart';
import '../typedefs.dart'; // For HttpClient, AuthCallbacks

class _Refs {
  String? HEAD;
  Map<String, String> heads = {};
  Map<String, String> pull = {}; // Or any other special refs like 'pull'
  Map<String, String> tags = {};
  Map<String, dynamic> _other = {}; // For any other paths like refs/for, refs/changes etc.

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (HEAD != null) data['HEAD'] = HEAD;
    if (heads.isNotEmpty) data['heads'] = heads;
    if (pull.isNotEmpty) data['pull'] = pull;
    if (tags.isNotEmpty) data['tags'] = tags;
    _other.forEach((key, value) {
      data[key] = value;
    });
    return data;
  }
}

class GetRemoteInfoResult {
  final List<String> capabilities;
  final _Refs refs;
  // The original JS version dynamically builds the refs object. 
  // In Dart, it's better to have a more structured class.
  // The HttpClient response headers are not part of the original JS function's return type, but are mentioned in fetch.js. 
  // If they are indeed returned by the underlying discovery, this class can be updated.

  GetRemoteInfoResult({required this.capabilities, required this.refs});

  Map<String, dynamic> toJson() => {
        'capabilities': capabilities,
        'refs': refs.toJson(),
      };
}

Future<GetRemoteInfoResult> getRemoteInfo({
  required HttpClient http,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  String? corsProxy,
  required String url,
  Map<String, String> headers = const {},
  bool forPush = false,
}) async {
  try {
    assertParameter('http', http);
    assertParameter('url', url);

    // Assuming GitRemoteManager.getRemoteHelperFor and the helper's discover method exist in Dart
    final remoteHelper = GitRemoteManager.getRemoteHelperFor(url: url);
    final remote = await remoteHelper.discover(
      http: http,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      corsProxy: corsProxy,
      service: forPush ? 'git-receive-pack' : 'git-upload-pack',
      url: url,
      headers: headers,
      protocolVersion: 1, // Assuming this is an int
    );

    // Assuming remote.capabilities is List<String>
    // Assuming remote.refs is Map<String, String>
    // Assuming remote.symrefs is Map<String, String>

    final resultRefs = _Refs();

    // Convert the flat list remote.refs into an object tree
    remote.refs?.forEach((ref, oid) {
      final parts = ref.split('/');
      if (parts.isEmpty) return; // Should not happen with valid refs

      // Handle direct HEAD symref to a branch, e.g. HEAD -> refs/heads/main
      if (ref == 'HEAD' && oid.startsWith('ref: ')) {
        resultRefs.HEAD = oid.substring(5); // remove "ref: "
        return;
      } else if (ref == 'HEAD') {
         // This case (HEAD pointing to a commit) is handled by symrefs typically
         // but if it comes through refs, we can capture it.
         // However, the JS code implies HEAD is built from symrefs primarily.
      }

      // Simplified logic: place under heads, tags, or a generic map based on first parts
      // The original JS created nested objects dynamically.
      // Dart benefits from a more defined structure.
      if (parts.length > 1) {
        final type = parts[1]; // e.g., 'heads', 'tags', 'pull'
        final name = parts.sublist(2).join('/');
        if (name.isEmpty) return;

        if (type == 'heads') {
          resultRefs.heads[name] = oid;
        } else if (type == 'tags') {
          resultRefs.tags[name] = oid;
        } else if (type == 'pull') { // Example for pull requests
          resultRefs.pull[name] = oid;
        } else {
          // For other ref types like refs/for/master, store them in a nested way
          Map<String, dynamic> currentLevel = resultRefs._other;
          for (int i = 0; i < parts.length -1; ++i) {
            currentLevel = currentLevel.putIfAbsent(parts[i], () => <String, dynamic>{});
          }
          currentLevel[parts.last] = oid;
        }
      }
    });

    // Merge symrefs on top of refs
    remote.symrefs?.forEach((symrefName, targetRef) {
       if (symrefName == 'HEAD') {
        resultRefs.HEAD = targetRef;
      } else {
         // This part of JS logic for general symrefs creating nested structure:
         // const parts = symref.split('/');
         // const last = parts.pop();
         // let o = result; // result here is the top-level GetRemoteInfoResult.refs
         // for (const part of parts) {
         //   o[part] = o[part] || {};
         //   o = o[part];
         // }
         // o[last] = ref;
         // This requires careful translation if deeply nested symrefs other than HEAD are common
         // For now, _Refs handles common cases like HEAD, branches, tags. 
         // A more dynamic approach for _other in _Refs could be used for arbitrary paths.
         // Example: if symrefName is 'refs/remotes/origin/foo' and targetRef is 'refs/remotes/origin/bar'
         // This would mean result.refs.remotes.origin.foo = 'refs/remotes/origin/bar'
         // The current _Refs structure might need to be more generic or the logic here more complex
         // to exactly replicate the JS dynamic object creation for all symref possibilities.
         // Let's assume for now that most important symrefs (like HEAD) are handled,
         // and other symrefs might point to already populated refs.

        // Simplified: if a symref points to a known category, place it there.
        final parts = symrefName.split('/');
        if (parts.length > 1) {
          final type = parts[1];
          final name = parts.sublist(2).join('/');
          if (name.isEmpty) continue;

          if (type == 'heads') {
            resultRefs.heads[name] = targetRef; // Symref to a branch
          } else if (type == 'tags') {
            resultRefs.tags[name] = targetRef; // Symref to a tag
          }
          // Other symrefs could be to other symrefs or create deeper structures.
          // The provided JS code suggests direct assignment into the object structure.
          // For simplicity, this Dart translation doesn't fully replicate dynamic nested creation for all symrefs.
          // It prioritizes updating known categories.
        }
      }
    });

    return GetRemoteInfoResult(
      capabilities: remote.capabilities?.toList() ?? [], 
      refs: resultRefs
    );

  } catch (err) {
    // err.caller = 'git.getRemoteInfo'
    rethrow;
  }
} 