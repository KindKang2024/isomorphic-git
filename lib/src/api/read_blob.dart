import 'dart:typed_data';

import '../commands/read_blob.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

// @typedef {Object} ReadBlobResult - The object returned has the following schema:
// @property {string} oid
// @property {Uint8Array} blob
class ReadBlobResult {
  String oid;
  Uint8List blob;

  ReadBlobResult({required this.oid, required this.blob});
}

/// Read a blob object directly
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [oid] - The SHA-1 object id to get. Annotated tags, commits, and trees are peeled.
/// [filepath] - Don't return the object with `oid` itself, but resolve `oid` to a tree and then return the blob object at that filepath.
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<ReadBlobResult>] that resolves successfully with a blob object description.
/// See [ReadBlobResult]
///
/// Example:
/// ```dart
/// // Get the contents of 'README.md' in the main branch.
/// String commitOid = await git.resolveRef(fs: fs, dir: '/tutorial', ref: 'main');
/// print(commitOid);
/// ReadBlobResult result = await git.readBlob(
///   fs: fs,
///   dir: '/tutorial',
///   oid: commitOid,
///   filepath: 'README.md',
/// );
/// print(String.fromCharCodes(result.blob));
/// ```
Future<ReadBlobResult> readBlob({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String oid,
  String? filepath,
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);

    // Assuming _readBlob is adapted to Dart and FileSystem constructor is as well
    var result = await _readBlob(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: effectiveGitdir,
      oid: oid,
      filepath: filepath,
    );
    // Assuming _readBlob now returns a Map or a class that can be destructured or converted to ReadBlobResult
    // For now, let's assume it returns a Map
    if (result is Map) {
      return ReadBlobResult(oid: result['oid'], blob: result['blob']);
    }
    // Or if it returns an object that matches ReadBlobResult structure
    // return ReadBlobResult(oid: result.oid, blob: result.blob);
    // This part needs adjustment based on how _readBlob is implemented in Dart
    throw UnimplementedError('_readBlob result type not handled');
  } catch (e) {
    // In Dart, it's more common to rethrow the original error or a new error that wraps it.
    // Adding a caller property like in JS is not standard.
    // One way is to print or log: print('Error in git.readBlob: $e');
    rethrow;
  }
}
