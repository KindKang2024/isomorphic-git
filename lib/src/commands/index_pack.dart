import 'dart:async';
import 'dart:typed_data';

import '../models/file_system.dart';
import '../models/git_pack_index.dart';
import '../storage/read_object.dart';
import '../utils/join.dart';
import '../utils/callbacks.dart';

class IndexPackResult {
  final List<String> oids;
  IndexPackResult({required this.oids});
}

Future<IndexPackResult> indexPack({
  required FileSystem fs,
  required dynamic cache,
  ProgressCallback? onProgress,
  String? dir, // dir is deprecated, use gitdir
  required String gitdir,
  required String filepath,
}) async {
  try {
    final fullFilepath = dir != null
        ? join(dir, filepath)
        : join(gitdir, filepath);
    // ^ prefer gitdir, but keep dir for backward compatibility if absolutely needed by calling code
    // However, the original JS seems to always join dir and filepath, which might be an issue if dir is not the worktree root.
    // Safest is to assume filepath is relative to gitdir if dir is not provided, or relative to workspace if dir is provided (but this needs clarification from JS logic)
    // For now, let's assume filepath is relative to `dir` if `dir` is provided, else relative to `gitdir`.
    // If `dir` is the workdir, and `filepath` is like `.git/objects/pack/pack-....pack`, then `join(dir, filepath)` is correct.
    // If `filepath` is just `objects/pack/pack-....pack`, it should be joined with `gitdir`.
    // The JS code `filepath = join(dir, filepath)` implies `filepath` is relative to `dir`.
    // Let's assume `filepath` passed is already the correct path relative to `dir` (which is usually the worktree root).

    Uint8List pack = await fs.read(fullFilepath) as Uint8List;

    Future<ReadObjectResult> getExternalRefDelta(String oid) =>
        readObject(fs: fs, cache: cache, gitdir: gitdir, oid: oid);

    final idx = await GitPackIndex.fromPack(
      pack: pack,
      getExternalRefDelta: getExternalRefDelta,
      onProgress: onProgress,
    );

    await fs.write(
      fullFilepath.replaceFirst(RegExp(r'\.pack$'), '.idx'),
      await idx.toBuffer(),
    );
    return IndexPackResult(oids: idx.hashes.toList());
  } catch (err) {
    // Consider creating a custom error class or re-throwing with more context if needed
    print('Error in git.indexPack: $err'); // Or use a proper logger
    rethrow;
  }
}
