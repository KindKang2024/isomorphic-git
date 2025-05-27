import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../http_client_interface.dart';

GitHttpClient getHttpClient() => WebHttpClient();

class WebHttpClient implements GitHttpClient {
  @override
  Future<GitHttpResponse> request({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    Stream<Uint8List>? body,
    Function(int, int)?
    onProgress, // Note: onProgress for upload is not directly supported with HttpRequest and stream
  }) async {
    final completer = Completer<GitHttpResponse>();
    final xhr = html.HttpRequest();
    xhr.open(method, url);

    headers.forEach((key, value) {
      xhr.setRequestHeader(key, value);
    });

    // Browsers typically don't support streaming request bodies with XMLHttpRequest easily.
    // The original JS code also collected the body for fetch.
    // We'll collect the stream into a single Uint8List.
    List<int> bodyBytes = [];
    if (body != null) {
      await for (var chunk in body) {
        bodyBytes.addAll(chunk);
      }
    }

    xhr.onLoad.listen((event) {
      if (xhr.status == null) {
        completer.completeError(Exception('Request failed: status is null'));
        return;
      }

      final responseHeaders = <String, String>{};
      // xhr.responseHeaders is a single string, need to parse it.
      final headerString = xhr.getAllResponseHeaders();
      if (headerString != null) {
        final lines = headerString.trim().split('\r\n');
        for (var line in lines) {
          final parts = line.split(': ');
          if (parts.length == 2) {
            responseHeaders[parts[0].toLowerCase()] = parts[1];
          }
        }
      }

      // Create a stream from the response.
      // xhr.response can be of different types based on xhr.responseType.
      // By default, it's a string or an ArrayBuffer if responseType is set.
      // We expect bytes.
      Stream<Uint8List> responseBodyStream;
      if (xhr.response is ByteBuffer) {
        responseBodyStream = Stream.value(
          (xhr.response as ByteBuffer).asUint8List(),
        );
      } else if (xhr.response is String) {
        // This case might occur if the server doesn't set Content-Type properly
        // or if responseType wasn't set to 'arraybuffer'.
        // For simplicity, we assume it should be bytes.
        responseBodyStream = Stream.value(
          Uint8List.fromList((xhr.response as String).codeUnits),
        );
      } else if (xhr.response == null) {
        responseBodyStream = Stream.fromIterable([]);
      } else {
        // Fallback for other types or if direct byte access isn't straightforward
        // This might need refinement based on expected response types.
        try {
          responseBodyStream = Stream.value(
            Uint8List.fromList(xhr.response.toString().codeUnits),
          );
        } catch (e) {
          responseBodyStream = Stream.error(
            Exception('Unsupported response type: ${xhr.response.runtimeType}'),
          );
        }
      }

      completer.complete(
        GitHttpResponse(
          url: xhr.responseUrl ?? url,
          method:
              method, // XHR doesn't easily expose the request method in the response
          statusCode: xhr.status!,
          statusMessage: xhr.statusText,
          body: responseBodyStream,
          headers: responseHeaders,
        ),
      );
    });

    xhr.onError.listen((event) {
      completer.completeError(Exception('Request failed: ${xhr.statusText}'));
    });

    // Handle onProgress for downloads if needed (xhr.onProgress)
    if (onProgress != null) {
      xhr.onProgress.listen((html.ProgressEvent event) {
        if (event.lengthComputable ?? false) {
          onProgress(event.loaded ?? 0, event.total ?? 0);
        }
      });
    }

    // Set response type to get ArrayBuffer for binary data
    xhr.responseType = 'arraybuffer';

    if (bodyBytes.isNotEmpty) {
      xhr.send(Uint8List.fromList(bodyBytes));
    } else {
      xhr.send();
    }

    return completer.future;
  }
}
