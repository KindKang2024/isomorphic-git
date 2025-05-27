import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/http_error.dart';
import '../errors/smart_http_error.dart';
import '../errors/user_canceled_error.dart';
import '../utils/calculate_basic_auth_header.dart';
import '../utils/extract_auth_from_url.dart';
import '../wire/parse_refs_ad_response.dart';
// Assuming typedefs are defined or will be created
// import '../typedefs.dart';

// Define a type for HttpClient in Dart, typically from package:http
typedef HttpClient = http.Client;
typedef ProgressCallback = void Function(int loaded, int total);
typedef Auth = Map<String, dynamic>; // Simplified Auth type
typedef AuthCallback = Future<Auth?> Function(String url, Auth auth);
typedef AuthFailureCallback = Future<Auth?> Function(String url, Auth auth);
typedef AuthSuccessCallback = Future<void> Function(String url, Auth auth);

String _corsProxify(String corsProxy, String url) {
  if (corsProxy.endsWith('?')) {
    return '$corsProxy$url';
  } else {
    return '$corsProxy/${url.replaceFirst(RegExp(r'^https?://'), '')}';
  }
}

void _updateHeaders(Map<String, String> headers, Auth auth) {
  if (auth['username'] != null || auth['password'] != null) {
    headers['Authorization'] = calculateBasicAuthHeader(
      auth['username'] as String?,
      auth['password'] as String?,
    );
  }
  if (auth['headers'] != null) {
    (auth['headers'] as Map<String, String>).forEach(
      (key, value) => headers[key] = value,
    );
  }
}

Future<Map<String, dynamic>> _stringifyBody(http.Response res) async {
  try {
    final data = res.bodyBytes;
    final response = utf8.decode(data);
    final preview = response.length < 256
        ? response
        : '${response.substring(0, 256)}...';
    return {'preview': preview, 'response': response, 'data': data};
  } catch (e) {
    return {};
  }
}

class GitRemoteHTTP {
  static Future<List<String>> capabilities() async {
    return ['discover', 'connect'];
  }

  static Future<RemoteHTTP> discover({
    required HttpClient httpClient,
    ProgressCallback? onProgress,
    AuthCallback? onAuth,
    AuthFailureCallback? onAuthFailure,
    AuthSuccessCallback? onAuthSuccess,
    String? corsProxy,
    required String service,
    required String url,
    required Map<String, String> headers,
    required int protocolVersion, // 1 or 2
  }) async {
    var extracted = extractAuthFromUrl(url);
    var currentUrl = extracted.url;
    var currentAuth = extracted.auth ?? <String, dynamic>{};

    final proxifiedURL = corsProxy != null
        ? _corsProxify(corsProxy, currentUrl)
        : currentUrl;

    _updateHeaders(headers, currentAuth);

    if (protocolVersion == 2) {
      headers['Git-Protocol'] = 'version=2';
    }

    http.Response res;
    bool tryAgain;
    bool providedAuthBefore = false;

    do {
      // Simulating onProgress with http package is tricky for GET,
      // as it doesn't expose chunk-wise progress for downloads easily.
      // For POST, one might use http.StreamedRequest.
      final request = http.Request(
        'GET',
        Uri.parse('$proxifiedURL/info/refs?service=$service'),
      );
      request.headers.addAll(headers);

      final streamedResponse = await httpClient.send(request);
      res = await http.Response.fromStream(streamedResponse);

      // Default loop behavior
      tryAgain = false;

      if (res.statusCode == 401 || res.statusCode == 203) {
        final getAuth = providedAuthBefore ? onAuthFailure : onAuth;
        if (getAuth != null) {
          var newAuth = await getAuth(currentUrl, {
            ...currentAuth,
            'headers': {...headers},
          });

          if (newAuth != null && newAuth['cancel'] == true) {
            throw UserCanceledError();
          } else if (newAuth != null) {
            currentAuth = newAuth;
            _updateHeaders(headers, currentAuth);
            providedAuthBefore = true;
            tryAgain = true;
          }
        }
      } else if (res.statusCode == 200 &&
          providedAuthBefore &&
          onAuthSuccess != null) {
        await onAuthSuccess(currentUrl, currentAuth);
      }
    } while (tryAgain);

    if (res.statusCode != 200) {
      final bodyDetails = await _stringifyBody(res);
      throw HttpError(
        res.statusCode,
        res.reasonPhrase ?? 'Unknown',
        bodyDetails['response'] as String?,
      );
    }

    final contentType = res.headers['content-type'];
    if (contentType == 'application/x-$service-advertisement') {
      // parseRefsAdResponse expects a Stream<List<int>> which res.bodyBytes is not.
      // It needs to be adapted if the original expects chunked reading.
      // For simplicity here, using res.bodyBytes directly assuming it fits memory.
      final remoteHTTP = await parseRefsAdResponse([
        res.bodyBytes,
      ], service: service);
      remoteHTTP.auth = currentAuth;
      return remoteHTTP;
    } else {
      final bodyDetails = await _stringifyBody(res);
      try {
        // Same as above, res.bodyBytes might need to be a stream.
        final remoteHTTP = await parseRefsAdResponse([
          bodyDetails['data'] as Uint8List,
        ], service: service);
        remoteHTTP.auth = currentAuth;
        return remoteHTTP;
      } catch (e) {
        throw SmartHttpError(
          bodyDetails['preview'] as String?,
          bodyDetails['response'] as String?,
        );
      }
    }
  }

  static Future<http.Response> connect({
    required HttpClient httpClient,
    ProgressCallback? onProgress,
    String? corsProxy,
    required String service,
    required String url,
    required Auth auth,
    required List<Uint8List>
    body, // Assuming body is a list of Uint8List chunks
    required Map<String, String> headers,
  }) async {
    var currentUrl = url;
    final urlAuthDetails = extractAuthFromUrl(currentUrl);
    if (urlAuthDetails.url.isNotEmpty) currentUrl = urlAuthDetails.url;

    if (corsProxy != null) currentUrl = _corsProxify(corsProxy, currentUrl);

    headers['content-type'] = 'application/x-$service-request';
    headers['accept'] = 'application/x-$service-result';
    _updateHeaders(headers, auth);

    // For POST with progress, http.StreamedRequest is more appropriate in Dart.
    // Concatenating Uint8List chunks for simplicity here.
    final flatBody = body.expand((x) => x).toList();

    final request = http.Request('POST', Uri.parse('$currentUrl/$service'));
    request.headers.addAll(headers);
    request.bodyBytes = Uint8List.fromList(flatBody);

    // onProgress for uploads is more involved, typically requiring custom logic
    // or a package that supports it with http.StreamedRequest.

    final streamedResponse = await httpClient.send(request);
    final res = await http.Response.fromStream(streamedResponse);

    if (res.statusCode != 200) {
      final bodyDetails = await _stringifyBody(res);
      throw HttpError(
        res.statusCode,
        res.reasonPhrase ?? 'Unknown',
        bodyDetails['response'] as String?,
      );
    }
    return res;
  }
}

// Placeholder for RemoteHTTP type if it's a custom class
// This would be defined based on the output of parseRefsAdResponse
class RemoteHTTP {
  Auth? auth;
  // Other properties from parseRefsAdResponse
  Map<String, String> refs;
  Map<String, String> symrefs;
  List<List<String>>? capabilities; // Example: [ ['version', '2'] ]
  List<String>? shallow;

  RemoteHTTP({
    this.auth,
    this.refs = const {},
    this.symrefs = const {},
    this.capabilities,
    this.shallow,
  });
}
