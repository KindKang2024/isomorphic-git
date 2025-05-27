import '../errors/unknown_transport_error.dart';
import '../errors/url_parse_error.dart';
import '../utils/translate_ssh_to_http.dart';
import 'git_remote_http.dart'; // Assuming GitRemoteHTTP is the Dart class

class _RemoteUrlParts {
  final String transport;
  final String address;

  _RemoteUrlParts({required this.transport, required this.address});
}

_RemoteUrlParts? _parseRemoteUrl({required String url}) {
  // The stupid "shorter scp-like syntax"
  if (url.startsWith('git@')) {
    return _RemoteUrlParts(transport: 'ssh', address: url);
  }
  final matches = RegExp(r'(\w+)(://|::)(.*)').firstMatch(url);
  if (matches == null) return null;

  if (matches.group(2) == '://') {
    return _RemoteUrlParts(
      transport: matches.group(1)!,
      address: matches.group(0)!,
    );
  }

  if (matches.group(2) == '::') {
    return _RemoteUrlParts(
      transport: matches.group(1)!,
      address: matches.group(3)!,
    );
  }
  return null; // Should not happen if regex matches
}

// Define a common interface or base class for remote helpers if they differ more significantly
// For now, GitRemoteHTTP is directly used.
// typedef RemoteHelper = Type; // In Dart, Type can represent a class type

class GitRemoteManager {
  // In Dart, we'd typically pass the specific helper or use a factory pattern
  // rather than returning a Type. For direct translation:
  static Type getRemoteHelperFor({required String url}) {
    // TODO: clean up the remoteHelper API and move into PluginCore
    final remoteHelpers = <String, Type>{};
    remoteHelpers['http'] = GitRemoteHTTP;
    remoteHelpers['https'] = GitRemoteHTTP;

    final parts = _parseRemoteUrl(url: url);
    if (parts == null) {
      throw UrlParseError(url);
    }
    if (remoteHelpers.containsKey(parts.transport)) {
      return remoteHelpers[parts.transport]!;
    }
    throw UnknownTransportError(
      url,
      parts.transport,
      parts.transport == 'ssh' ? translateSSHtoHTTP(url) : null,
    );
  }

  // If you need to instantiate the helper, you might have a method like this:
  // static dynamic createRemoteHelperFor({required String url}) {
  //   final helperType = getRemoteHelperFor(url: url);
  //   if (helperType == GitRemoteHTTP) {
  //     return GitRemoteHTTP(); // Or pass necessary constructor args
  //   }
  //   // Add other types if necessary
  //   throw Exception('Cannot create instance for $helperType');
  // }
}
