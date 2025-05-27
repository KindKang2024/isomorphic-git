Map<String, dynamic> extractAuthFromUrl(String url) {
  final userpassMatch = RegExp(r'^https?:\/\/([^/]+)@').firstMatch(url);
  if (userpassMatch == null) return {'url': url, 'auth': {}};
  final userpass = userpassMatch.group(1)!;
  final parts = userpass.split(':');
  final username = parts.isNotEmpty ? parts[0] : '';
  final password = parts.length > 1 ? parts[1] : '';
  final safeUrl = url.replaceFirst('$userpass@', '');
  return {
    'url': safeUrl,
    'auth': {'username': username, 'password': password},
  };
}
