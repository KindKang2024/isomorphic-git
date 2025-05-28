import 'dart:async';

import '../models/file_system.dart';
import '../utils/join.dart';

/// Removes the directory at the specified filepath recursively. Used internally to replicate the behavior of
/// fs.promises.rm({ recursive: true, force: true }) from Node.js 14 and above when not available. If the provided
/// filepath resolves to a file, it will be removed.
Future<void> rmRecursive(FileSystem fs, String filepath) async {
  List<String>? entries;
  try {
    entries = await fs.readdir(filepath);
  } catch (e) {
    // If readdir fails, it might be a file or a non-existent path.
    // Attempt to remove it as a file.
    // The `force: true` behavior implies not throwing if it doesn't exist.
    try {
      await fs.rm(filepath);
    } catch (e2) {
      // If both readdir and rm fail, and we want to mimic `force: true`,
      // we might choose to ignore this error if the intent is to ensure it's gone.
      // However, the original JS doesn't explicitly handle fs.rm throwing on non-existence for files.
      // For now, let it throw if fs.rm fails after readdir failed.
    }
    return;
  }

  if (entries == null) {
    // This case is for when readdir returns null (e.g. it's a file, not a directory)
    // In the JS, this would mean it's a file, so `fs.rm(filepath)` is called.
    // This is now handled in the catch block for `fs.readdir` for cleaner logic.
    // However, to be extremely close to the original if `entries` can be null from `readdir` for a file:
    try {
      await fs.rm(filepath);
    } catch (e) {
      // Ignore if it's already gone, similar to `force: true`
    }
  } else if (entries.isNotEmpty) {
    await Future.wait(
      entries.map((entry) async {
        final subpath = join([filepath, entry]);
        final stat = await fs.lstat(subpath);
        if (stat == null) return;
        if (stat.isDirectory()) {
          await rmRecursive(fs, subpath);
        } else {
          await fs.rm(subpath);
        }
      }),
    );
    await fs.rmdir(filepath); // Remove the now-empty directory
  } else {
    // Directory is empty
    await fs.rmdir(filepath);
  }
}
