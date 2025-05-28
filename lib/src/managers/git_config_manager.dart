import '../models/git_config.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/file_system.dart';

class GitConfigManager {
  static Future<GitConfig> get({
    required FileSystem fs,
    required String? gitdir,
  }) async {
    // We can improve efficiency later if needed.
    // TODO: read from full list of git config files
    final file = File(p.join(gitdir!, 'config'));
    final text = await file.readAsString();
    return GitConfig.from(text);
  }

  static Future<void> save({
    required FileSystem fs,
    required String gitdir,
    required GitConfig config,
  }) async {
    // We can improve efficiency later if needed.
    // TODO: handle saving to the correct global/user/repo location
    final file = File(p.join(gitdir, 'config'));
    await file.writeAsString(config.toString());
  }
}
