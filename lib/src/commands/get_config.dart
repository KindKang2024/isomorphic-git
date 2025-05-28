import 'dart:async';

import '../managers/git_config_manager.dart';
import '../models/file_system.dart';
import '../utils/join.dart';

Future<dynamic> getConfig({
  required FileSystem fs,
  required String? dir,
  required String? gitdir ,
  required String path,
}) async {
  final usedGitdir = gitdir ?? join(dir, '.git');

  final config = await GitConfigManager.get(fs: fs, gitdir: usedGitdir);
  return config.get(path);
}
