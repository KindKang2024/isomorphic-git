import 'dart:async';

import '../managers/git_config_manager.dart';
import '../models/file_system.dart';

Future<List<dynamic>> getConfigAll({
  required FileSystem fs,
  required String gitdir,
  required String path,
}) async {
  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
  return await config.getAll(
    path,
  ); // Ensure getAll is async if it involves async operations
}
