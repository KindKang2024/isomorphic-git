// import '../typedefs.dart'; // Dart handles types

import '../commands/add_remote.dart'
    show addRemoteInternal; // Assuming _addRemote is addRemoteInternal
import '../models/file_system.dart'; // Assumes FsClient is here
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Add or update a remote
Future<void> addRemote({
  required dynamic fs, // Should be FsClient
  String? dir,
  String? gitdir,
  required String remote,
  required String url,
  bool force = false,
}) async {
  final effectiveGitdir = gitdir ?? (dir != null ? join(dir, '.git') : null);

  if (effectiveGitdir == null) {
    throw ArgumentError('Either dir or gitdir must be provided.');
  }

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('remote', remote);
    assertParameter('url', url);

    await addRemoteInternal(
      fs: FileSystem(fs), // Pass FileSystem instance
      gitdir: effectiveGitdir,
      remote: remote,
      url: url,
      force: force,
    );
  } catch (err) {
    // err.caller = 'git.addRemote'; // JS specific
    print("Error in git.addRemote: $err");
    rethrow;
  }
}
