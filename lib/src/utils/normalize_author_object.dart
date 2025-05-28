import 'package:isomorphic_git/src/storage/read_object_loose.dart';

import '../utils/assign_defined.dart';
import '../commands/get_config.dart' as commands_get_config;
import '../models/file_system.dart';

Future<Map<String, dynamic>?> normalizeAuthorObject({
  required FileSystem fs,
  String? gitdir,
  Map<String, dynamic>? author,
  Map<String, dynamic>? commit,
}) async {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

  dynamic nameFromConfig;
  dynamic emailFromConfig;

  if (gitdir != null) {
    nameFromConfig = await commands_get_config.getConfig(
      fs: fs,
      gitdir: gitdir,
      path: 'user.name',
    );
    emailFromConfig = await commands_get_config.getConfig(
      fs: fs,
      gitdir: gitdir,
      path: 'user.email',
    );
  }

  final defaultAuthor = <String, dynamic>{
    'name': nameFromConfig,
    'email': emailFromConfig ?? '',
    'timestamp': timestamp,
    'timezoneOffset': DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
    ).timeZoneOffset.inMinutes,
  };

  final normalizedAuthor = assignDefined({}, [
    defaultAuthor,
    commit?['author'],
    author,
  ]);

  if (normalizedAuthor['name'] == null) {
    return null;
  }

  return normalizedAuthor;
}
