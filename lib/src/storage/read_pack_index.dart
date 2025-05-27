import 'dart:typed_data';

import '../models/git_pack_index.dart';
import '../utils/fs.dart';

// TODO: Consider a more Dart-idiomatic way to handle caching if needed.
// const PackfileCache = Symbol('PackfileCache');

Future<GitPackIndex> _loadPackIndex({
  required FileSystem fs,
  required String filename,
  required Function getExternalRefDelta,
  // TODO: emitter and emitterPrefix are not used in the original code, consider removing or implementing.
  // required Emitter emitter,
  // required String emitterPrefix,
}) async {
  final Uint8List idx = await fs.read(filename);
  return GitPackIndex.fromIdx(
    idx: idx,
    getExternalRefDelta: getExternalRefDelta,
  );
}

Future<GitPackIndex> readPackIndex({
  required FileSystem fs,
  required Map<String, dynamic> cache,
  required String filename,
  required Function getExternalRefDelta,
  // TODO: emitter and emitterPrefix are not used in the original code, consider removing or implementing.
  // required Emitter emitter,
  // required String emitterPrefix,
}) async {
  // Try to get the packfile index from the in-memory cache
  // Dart doesn't have Symbols in the same way, using a String key for the cache.
  const String packfileCacheKey = 'PackfileCache';
  if (!cache.containsKey(packfileCacheKey)) {
    cache[packfileCacheKey] = <String, Future<GitPackIndex>>{};
  }

  final Map<String, Future<GitPackIndex>> packfileCache =
      cache[packfileCacheKey]! as Map<String, Future<GitPackIndex>>;

  Future<GitPackIndex>? p = packfileCache[filename];
  if (p == null) {
    p = _loadPackIndex(
      fs: fs,
      filename: filename,
      getExternalRefDelta: getExternalRefDelta,
      // emitter: emitter,
      // emitterPrefix: emitterPrefix,
    );
    packfileCache[filename] = p;
  }
  return p;
}
