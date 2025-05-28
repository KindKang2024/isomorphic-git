import '../utils/assign_defined.dart';
import '../commands/get_config.dart';

Future<Map<String, dynamic>?> normalizeCommitterObject({
  required dynamic fs,
  String? gitdir,
  Map<String, dynamic>? author,
  Map<String, dynamic>? committer,
  Map<String, dynamic>? commit,
}) async {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

  final defaultCommitter = <String, dynamic>{
    'name': await getConfig(fs: fs,  path: 'user.name'),
    'email':
        (await getConfig(fs: fs, gitdir: gitdir, path: 'user.email')) ?? '',
    'timestamp': timestamp,
    'timezoneOffset': DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
    ).timeZoneOffset.inMinutes,
  };

  final normalizedCommitter = assignDefined({}, [
    defaultCommitter,
    commit != null ? commit['committer'] as Map<String, dynamic>? : null,
    author,
    committer,
  ]);

  if (normalizedCommitter['name'] == null) {
    return null;
  }
  return normalizedCommitter;
}
