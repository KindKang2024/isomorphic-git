import 'dart:async';
import 'dart:typed_data';

import '../models/git_pack_index.dart';
import '../models/file_system.dart'; // Assuming a file system shim for 'fs'

// Using a simple in-memory cache for packfiles, similar to the JS version.
// For a more robust solution, consider a more sophisticated caching mechanism.
final Map<String, Future<GitPackIndex?>> _packfileCache = {};

Future<GitPackIndex?> _loadPackIndex({
  required FileSystem fs,
  required String filename,
  required Future<Uint8List> Function(String oid) getExternalRefDelta,
  // emitter and emitterPrefix are not directly translated as their usage
  // in the original JS context (likely for events) might need a different approach in Dart.
}) async {
  final idx = await fs.read(filename);
  if (idx == null) {
    // Or throw an error, depending on desired behavior for missing files
    return null;
  }
  return GitPackIndex.fromIdx(idx: idx, getExternalRefDelta: getExternalRefDelta);
}

Future<GitPackIndex?> readPackIndex({
  required FileSystem fs,
  // 'cache' in JS was a general-purpose cache. Here we use a dedicated packfile cache.
  required String filename,
  required Future<Uint8List> Function(String oid) getExternalRefDelta,
  // emitter and emitterPrefix are omitted for now.
}) async {
  var p = _packfileCache[filename];
  if (p == null) {
    p = _loadPackIndex(
      fs: fs,
      filename: filename,
      getExternalRefDelta: getExternalRefDelta,
    );
    _packfileCache[filename] = p;
  }
  return p;
}