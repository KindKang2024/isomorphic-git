import 'dart:async';
import 'dart:typed_data';

import '../errors/invalid_filepath_error.dart';
import '../errors/not_found_error.dart';
import '../managers/git_index_manager.dart';
import '../models/file_system.dart';
import '../models/file_stat.dart'; // Assuming FileStat model exists
import '../storage/write_object.dart' as write_object;
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

Future<String?> updateIndex({
  required FsClient fs,
  required String dir,
  String? gitdir,
  Map<String, dynamic> cache = const {},
  required String filepath,
  String? oid,
  int? mode, // Defaults to 0o100644 in JS, Dart uses decimal 33188
  bool add = false,
  bool remove = false,
  bool force = false,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('filepath', filepath);

    final fsModel = FileSystem(fs);

    if (remove) {
      await GitIndexManager.acquire(fs: fsModel, gitdir: gitdir, cache: cache, (
        index,
      ) async {
        if (!force) {
          // Check if the file is still present in the working directory
          final fileStats = await fsModel.lstat(join(dir, filepath));

          if (fileStats != null) {
            if (fileStats.isDirectory) {
              // Removing directories should not work
              throw InvalidFilepathError('directory');
            }
            // Do nothing if we don't force and the file still exists in the workdir
            return;
          }
        }

        // Directories are not allowed, so we make sure the provided filepath exists in the index
        if (index.has(filepath: filepath)) {
          index.delete(filepath: filepath);
        }
      });
      return null; // Corresponds to `void` in JS for this branch
    }

    // Test if it is a file and exists on disk if `remove` is not provided, only if no oid is provided
    FileStat? fileStats;

    if (oid == null) {
      fileStats = await fsModel.lstat(join(dir, filepath));

      if (fileStats == null) {
        throw NotFoundError('file at "$filepath" on disk and "remove" not set');
      }

      if (fileStats.isDirectory) {
        throw InvalidFilepathError('directory');
      }
    }

    return await GitIndexManager.acquire(
      fs: fsModel,
      gitdir: gitdir,
      cache: cache,
      (index) async {
        if (!add && !index.has(filepath: filepath)) {
          // If the index does not contain the filepath yet and `add` is not set, we should throw
          throw NotFoundError('file at "$filepath" in index and "add" not set');
        }

        FileStat stats;
        if (oid == null) {
          stats = fileStats!;

          // Write the file to the object database
          Uint8List objectData;
          if (stats.isSymbolicLink) {
            // Assuming readlink returns String, convert to Uint8List
            final linkPath = await fsModel.readlink(join(dir, filepath));
            objectData = Uint8List.fromList(linkPath.codeUnits);
          } else {
            objectData = await fsModel.read(join(dir, filepath));
          }

          oid = await write_object.writeObject(
            fs: fsModel,
            gitdir: gitdir!,
            type: 'blob',
            format: 'content',
            object: objectData,
          );
        } else {
          // By default we use 0 for the stats of the index file
          stats = FileStat(
            // JS uses 0o100644 (octal) = 33188 (decimal)
            // JS uses 0o100755 (octal) = 33261 (decimal) for executable
            // JS uses 0o040000 (octal) = 16384 (decimal) for directory
            // JS uses 0o120000 (octal) = 40960 (decimal) for symlink
            mode: mode ?? 33188, // Default to 100644 (regular file)
            type: 'file', // Or determine from mode
            size: 0,
            ino: 0,
            mtimeMs: 0,
            ctimeMs: 0,
            uid: 0,
            gid: 0,
            dev: 0,
          );
        }

        index.insert(filepath: filepath, oid: oid!, stats: stats);

        return oid;
      },
    );
  } catch (err) {
    // err.caller = 'git.updateIndex'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
