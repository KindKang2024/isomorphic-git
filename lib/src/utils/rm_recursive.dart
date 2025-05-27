import 'dart:async';

import '../utils/join.dart';
import '../models/fs.dart'; // Assuming FS model is defined here
import '../models/stat.dart'; // Assuming Stat model for lstat results

Future<void> rmRecursive(FS fs, String filepath) async {
  List<String>? entries;
  try {
    entries = await fs.readdir(filepath);
  } catch (e) {
    // If readdir fails, it might be a file or a non-existent path.
    // Try to remove it as a file. If it doesn't exist, fs.rm should handle it gracefully or throw.
  }

  if (entries == null) {
    // Path is likely a file or does not exist, attempt to remove as a file.
    // `fs.rm` should ideally not throw if the file doesn't exist (like `force: true`)
    // or this part needs to be wrapped in a try-catch if `fs.rm` throws for non-existent files.
    try {
      await fs.rm(filepath);
    } catch (e) {
      // If fs.rm throws an error because the file/dir does not exist, we can ignore it,
      // as the goal is to ensure it's removed.
      // For other errors, we might want to rethrow them.
      // This depends on the exact behavior of `fs.rm` when a path doesn't exist.
      // For now, assuming `fs.rm` is like `rm -f`.
    }
  } else if (entries.isNotEmpty) {
    final futures = entries.map((entry) async {
      final subpath = join(filepath, entry);
      Stat? stat;
      try {
        stat = await fs.lstat(subpath);
      } catch (e) {
        // If lstat fails, the entry might have been removed by a parallel operation.
        // Or it's a broken symlink, etc. We can choose to ignore or log.
        return; // Skip if stat cannot be obtained
      }

      if (stat == null)
        return; // Should not happen if lstat doesn't throw for non-existent

      if (stat.isDirectory) {
        return rmRecursive(fs, subpath);
      } else {
        return fs.rm(subpath);
      }
    });
    await Future.wait(futures);
    try {
      await fs.rmdir(filepath); // Remove the now-empty directory
    } catch (e) {
      // Ignore if directory is already removed or was a file to begin with
    }
  } else {
    // Directory is empty
    try {
      await fs.rmdir(filepath);
    } catch (e) {
      // Ignore if directory is already removed or was a file to begin with
    }
  }
}
