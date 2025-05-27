import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:async_locks/async_locks.dart';

import '../errors/unmerged_paths_error.dart';
import '../models/git_index.dart';
import '../utils/compare_stats.dart';

// Using a simple in-memory cache for Dart.
// For more robust caching, consider packages like `stash`.
class _IndexCacheEntry {
  GitIndex? index;
  FileStat? stat;
}

final _indexCache = <String, _IndexCacheEntry>{};
final _lock = Lock(); // Global lock for index access

class GitIndexManager {
  static Future<T> acquire<T>({
    required Directory fs, // Dart's Directory or a custom FS wrapper
    required String gitdir,
    // Dart doesn't have a direct equivalent of a mutable cache object passed around.
    // We'll use a global or instance-based cache.
    // required Map<dynamic, dynamic> cache,
    bool allowUnmerged = true,
    required Future<T> Function(GitIndex) closure,
  }) async {
    final filepath = p.join(gitdir, 'index');
    T? result;
    List<String> unmergedPaths = [];

    await _lock.synchronized(() async {
      var cacheEntry = _indexCache[filepath];

      Future<void> updateCachedIndexFile() async {
        final file = File(filepath);
        if (!await file.exists()) {
          // If index doesn't exist, create an empty one
          final newIndex = GitIndex.empty();
          cacheEntry = _IndexCacheEntry()
            ..index = newIndex
            ..stat = null; // No stat for a new, empty index yet
          _indexCache[filepath] = cacheEntry!;
          return;
        }

        final stat = await file.stat();
        final rawIndexFile = await file.readAsBytes();

        final index = GitIndex.fromBuffer(Uint8List.fromList(rawIndexFile));
        cacheEntry = _IndexCacheEntry()
          ..index = index
          ..stat = stat;
        _indexCache[filepath] = cacheEntry!;
      }

      Future<bool> isIndexStale() async {
        if (cacheEntry == null || cacheEntry!.stat == null) return true;
        final file = File(filepath);
        if (!await file.exists()) return true; // Stale if file deleted
        final currentStat = await file.stat();
        return compareStats(cacheEntry!.stat!, currentStat);
      }

      if (cacheEntry == null || await isIndexStale()) {
        await updateCachedIndexFile();
      }

      final index = cacheEntry!.index!;
      unmergedPaths = index.unmergedPaths;

      if (unmergedPaths.isNotEmpty && !allowUnmerged) {
        throw UnmergedPathsError(unmergedPaths);
      }

      result = await closure(index);

      if (index.isDirty) {
        final buffer = await index.toBuffer();
        final file = File(filepath);
        await file.writeAsBytes(buffer, flush: true);
        cacheEntry!.stat = await file.stat();
        index.clearDirty();
      }
    });

    if (result == null) {
      throw Exception('Closure did not return a result or lock failed');
    }
    return result!;
  }
}
