import '../commands/init.dart' as commands_init;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // For FsClient

Future<void> init({
  required FsClient fs,
  bool bare = false,
  String?
  dir, // dir is nullable, but required if not bare for default gitdir calculation
  String? gitdir, // Can be provided, otherwise calculated
  String defaultBranch = 'master',
}) async {
  try {
    assertParameter('fs', fs);

    String effectiveGitdir;
    if (gitdir != null) {
      effectiveGitdir = gitdir;
    } else {
      if (dir == null) {
        // This case implies gitdir must be provided if dir is null,
        // as join(null, '.git') is invalid.
        // The original JS: gitdir = bare ? dir : join(dir, '.git')
        // If dir is null and gitdir is null:
        //   - if bare is true, gitdir becomes null (which assertParameter('gitdir', gitdir) would catch if null isn't allowed)
        //   - if bare is false, join(null, '.git') is an error.
        // So, dir is effectively required if gitdir is not provided.
        throw ArgumentError(
          '''dir' must be provided if 'gitdir' is not and 'bare' is false, or if 'bare' is true and 'gitdir' is not specified to be the 'dir'.''',
        );
      }
      effectiveGitdir = bare ? dir : join(dir, '.git');
    }
    assertParameter('gitdir', effectiveGitdir);

    if (!bare) {
      // If not a bare repo, dir must have been available for gitdir calculation or should be asserted.
      // Original JS: assertParameter('dir', dir).
      // If dir was null and bare was false, effectiveGitdir calculation would have failed if join doesn't handle null.
      // If dir was null and bare was true, gitdir became dir (null), assertParameter for gitdir covers it.
      // So, if not bare, `dir` must have been non-null if `gitdir` wasn't provided.
      if (dir == null && gitdir == null) {
        throw ArgumentError(
          ''''dir' must be provided for non-bare repositories if 'gitdir' is not specified.''',
        );
      }
      assertParameter(
        'dir',
        dir,
      ); // This will now only be called if dir is expected to be non-null.
    }

    await commands_init.init(
      fs: FileSystem(fs),
      bare: bare,
      dir:
          dir, // Pass dir, it might be used by _init internally even if gitdir is primary
      gitdir: effectiveGitdir,
      defaultBranch: defaultBranch,
    );
  } catch (err) {
    // err.caller = 'git.init'
    rethrow;
  }
}
