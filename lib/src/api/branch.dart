// import '../typedefs.dart'; // Dart handles types

import '../commands/branch.dart'
    show branchInternal; // Assuming _branch is branchInternal
import '../models/file_system.dart'; // Assumes FsClient is here
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Create a branch
Future<void> branch({
  required dynamic fs, // Should be FsClient
  String? dir,
  String? gitdir,
  required String ref,
  String? object, // In JS, defaults to 'HEAD' in the command layer
  bool checkout = false,
  bool force = false,
}) async {
  final effectiveGitdir = gitdir ?? (dir != null ? join(dir, '.git') : null);

  if (effectiveGitdir == null) {
    throw ArgumentError('Either dir or gitdir must be provided.');
  }

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('ref', ref);

    await branchInternal(
      fs: FileSystem(fs), // Pass FileSystem instance
      gitdir: effectiveGitdir,
      ref: ref,
      object:
          object, // Pass null if not provided, command layer should handle default
      checkout: checkout,
      force: force,
    );
  } catch (err) {
    // err.caller = 'git.branch'; // JS specific
    print("Error in git.branch: $err");
    rethrow;
  }
}
