import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../http_client_interface.dart';

GitHttpClient getHttpClient() => VmHttpClient();

class VmHttpClient implements GitHttpClient {
  final HttpClient _client;

  VmHttpClient() : _client = HttpClient();

  @override
  Future<GitHttpResponse> request({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    Stream<Uint8List>? body,
    Function(int, int)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final httpClientRequest = await _client.openUrl(method, uri);

    headers.forEach((key, value) {
      httpClientRequest.headers.set(key, value);
    });

    if (body != null) {
      // If onProgress is provided, we need to track bytes written.
      if (onProgress != null) {
        var totalBytes = 0;
        // Potentially get content length if available (e.g. from headers)
        // For simplicity, we assume it's not known or handled by the body stream itself.
        var bytesWritten = 0;

        // Get total length if possible (e.g. if body is a List<int>)
        // This is a simplification; a more robust solution would be needed for generic streams.
        if (headers.containsKey(HttpHeaders.contentLengthHeader)) {
          totalBytes = int.parse(headers[HttpHeaders.contentLengthHeader]!);
        }

        await httpClientRequest.addStream(
          body.transform(
            StreamTransformer.fromHandlers(
              handleData: (data, sink) {
                bytesWritten += data.length;
                onProgress(
                  bytesWritten,
                  totalBytes,
                ); // totalBytes might be 0 if unknown
                sink.add(data);
              },
            ),
          ),
        );
      } else {
        await httpClientRequest.addStream(body);
      }
    }

    final httpClientResponse = await httpClientRequest.close();

    final responseHeaders = <String, String>{};
    httpClientResponse.headers.forEach((key, values) {
      responseHeaders[key] = values.join(',');
    });

    return GitHttpResponse(
      url: url, // The original URL
      method: method, // The original method
      statusCode: httpClientResponse.statusCode,
      statusMessage: httpClientResponse.reasonPhrase,
      body: httpClientResponse
          .cast<Uint8List>(), // Ensure the stream is of type Uint8List
      headers: responseHeaders,
    );
  }
}
