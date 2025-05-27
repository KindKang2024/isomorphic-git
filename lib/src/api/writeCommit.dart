import 'dart:async';

import '../commands/write_commit.dart' as command_write_commit;
import '../models/file_system.dart';
import '../models/git_commit.dart'; // Assuming GitCommit model
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

Future<String> writeCommit({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required GitCommit commit,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('commit', commit);

    return await command_write_commit.writeCommit(
      fs: FileSystem(fs),
      gitdir: gitdir,
      commit: commit,
    );
  } catch (err) {
    // err.caller = 'git.writeCommit'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
