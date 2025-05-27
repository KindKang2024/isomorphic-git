import 'dart:convert';

String calculateBasicAuthHeader({String username = '', String password = ''}) {
  final credentials = '$username:$password';
  final encoded = base64.encode(utf8.encode(credentials));
  return 'Basic $encoded';
}
