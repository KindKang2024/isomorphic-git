import '../utils/assign_defined.dart';
// TODO: Implement or import _getConfig equivalent in Dart

Future<Map<String, dynamic>?> normalizeAuthorObject({
  required dynamic fs,
  String? gitdir,
  Map<String, dynamic>? author,
  Map<String, dynamic>? commit,
}) async {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

  final defaultAuthor = <String, dynamic>{
    'name': await _getConfig(fs: fs, gitdir: gitdir, path: 'user.name'),
    'email':
        (await _getConfig(fs: fs, gitdir: gitdir, path: 'user.email')) ?? '',
    'timestamp': timestamp,
    'timezoneOffset': DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
    ).timeZoneOffset.inMinutes,
  };

  final normalizedAuthor = assignDefined(
    {},
    defaultAuthor,
    commit?['author'],
    author,
  );

  if (normalizedAuthor['name'] == null) {
    return null;
  }

  return normalizedAuthor;
}
