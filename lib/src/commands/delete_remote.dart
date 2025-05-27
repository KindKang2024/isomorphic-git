import 'dart:async';

import '../managers/git_config_manager.dart';
import '../models/file_system.dart';

Future<void> deleteRemote({
  required FileSystem fs,
  required String gitdir,
  required String remote,
}) async {
  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
  await config.deleteSection('remote', remote);
  await GitConfigManager.save(fs: fs, gitdir: gitdir, config: config);
}
