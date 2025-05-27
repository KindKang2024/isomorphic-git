import 'dart:typed_data';

import '../managers/git_index_manager.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../models/stats.dart'; // Assuming a Stats model
import '../utils/assert_parameter.dart';
import '../utils/hash_object.dart';
import '../utils/join.dart';
import '../utils/resolve_filepath.dart';

/// Reset a file in the git index (aka staging area)
///
/// Note that this does NOT modify the file in the working directory.
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [filepath] - The path to the file to reset in the index
/// [ref] - A ref to the commit to use (default: 'HEAD')
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<void>] that resolves successfully once the git index has been updated.
///
/// Example:
/// ```dart
/// await git.resetIndex(fs: fs, dir: '/tutorial', filepath: 'README.md');
/// print('done');
/// ```
Future<void> resetIndex({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String filepath,
  String? ref = 'HEAD',
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');
  final fsModel = FileSystem(fs);

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('filepath', filepath);

    String? oid;
    String? workdirOid;

    try {
      oid = await GitRefManager.resolve(
        fs: fsModel,
        gitdir: effectiveGitdir,
        ref: ref ?? 'HEAD',
      );
    } catch (e) {
      if (ref != null && ref != 'HEAD') {
        // Only throw if ref was explicitly provided and not default
        rethrow;
      }
      // If ref is null or 'HEAD' and it fails, oid remains null (new repo case)
    }

    if (oid != null) {
      try {
        oid = await resolveFilepath(
          fs: fsModel,
          cache: cache,
          gitdir: effectiveGitdir,
          oid: oid,
          filepath: filepath,
        );
      } catch (e) {
        oid = null; // File is being reset to a "deleted" state
      }
    }

    Stats stats = Stats(
      ctimeMs: 0,
      mtimeMs: 0,
      dev: 0,
      ino: 0,
      mode: 0,
      uid: 0,
      gid: 0,
      size: 0,
    );

    if (dir != null) {
      try {
        Uint8List? object = await fsModel.read(join(dir, filepath));
        if (object != null) {
          workdirOid = await hashObject(
            gitdir: effectiveGitdir,
            type: 'blob',
            object: object,
          );
          if (oid == workdirOid) {
            stats = await fsModel.lstat(join(dir, filepath));
          }
        }
      } catch (e) {
        // File might not exist in workdir, or other read/lstat error. Default zero stats will be used.
      }
    }

    await GitIndexManager.acquire(
      fs: fsModel,
      gitdir: effectiveGitdir,
      cache: cache,
      callback: (index) async {
        index.delete(filepath: filepath);
        if (oid != null) {
          index.insert(filepath: filepath, stats: stats, oid: oid!);
        }
      },
    );
  } catch (e) {
    rethrow;
  }
}
