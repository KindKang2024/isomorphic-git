import '../utils/assign_defined.dart';
// TODO: Implement or import _getConfig equivalent in Dart

Future<Map<String, dynamic>?> normalizeCommitterObject({
  required dynamic fs,
  String? gitdir,
  Map<String, dynamic>? author,
  Map<String, dynamic>? committer,
  Map<String, dynamic>? commit,
}) async {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

  final defaultCommitter = <String, dynamic>{
    'name': await _getConfig(fs: fs, gitdir: gitdir, path: 'user.name'),
    'email':
        (await _getConfig(fs: fs, gitdir: gitdir, path: 'user.email')) ?? '',
    'timestamp': timestamp,
    'timezoneOffset': DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
    ).timeZoneOffset.inMinutes,
  };

  final normalizedCommitter = assignDefined(
    {},
    defaultCommitter,
    commit?['committer'],
    author,
    committer,
  );

  if (normalizedCommitter['name'] == null) {
    return null;
  }
  return normalizedCommitter;
}
