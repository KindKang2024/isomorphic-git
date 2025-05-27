import 'dart:async';

import '../managers/git_config_manager.dart';
import '../models/file_system.dart';

Future<dynamic> getConfig({
  required FileSystem fs,
  required String gitdir,
  required String path,
}) async {
  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
  return config.get(path);
}
