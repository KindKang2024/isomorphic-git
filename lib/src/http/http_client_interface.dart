import 'dart:async';
import 'dart:typed_data';

abstract class GitHttpClient {
  Future<GitHttpResponse> request({
    required String url,
    String method = 'GET',
    Map<String, String> headers = const {},
    Stream<Uint8List>? body,
    Function(int, int)? onProgress, // Placeholder for progress reporting
  });
}

class GitHttpRequest {
  final String url;
  final String method;
  final Map<String, String> headers;
  final Stream<Uint8List>? body;
  final Function(int, int)? onProgress;

  GitHttpRequest({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.onProgress,
  });
}

class GitHttpResponse {
  final String url;
  final String? method; // Method might not be available in all implementations
  final int statusCode;
  final String? statusMessage;
  final Stream<Uint8List> body;
  final Map<String, String> headers;

  GitHttpResponse({
    required this.url,
    this.method,
    required this.statusCode,
    this.statusMessage,
    required this.body,
    required this.headers,
  });
}
