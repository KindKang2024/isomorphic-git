import '../managers/git_index_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Remove a file from the git index (aka staging area)
///
/// Note that this does NOT delete the file in the working directory.
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [filepath] - The path to the file to remove from the index
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<void>] that resolves successfully once the git index has been updated.
///
/// Example:
/// ```dart
/// await git.remove(fs: fs, dir: '/tutorial', filepath: 'README.md');
/// print('done');
/// ```
Future<void> remove({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String filepath,
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('filepath', filepath);

    await GitIndexManager.acquire(
      fs: FileSystem(fs),
      gitdir: effectiveGitdir,
      cache: cache,
      callback: (index) async {
        index.delete(filepath: filepath);
      },
    );
  } catch (e) {
    rethrow;
  }
}
