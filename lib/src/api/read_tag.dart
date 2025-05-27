import '../commands/read_tag.dart';
import '../models/file_system.dart';
import '../models/tag_object.dart'; // Assuming this is the Dart equivalent of TagObject
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

class ReadTagResult {
  String oid; // SHA-1 object id of this tag
  TagObject tag; // the parsed tag object
  String payload; // PGP signing payload

  ReadTagResult({required this.oid, required this.tag, required this.payload});

  // Optional: Factory constructor if _readTag returns a map
  factory ReadTagResult.fromMap(Map<String, dynamic> map) {
    return ReadTagResult(
      oid: map['oid'],
      tag:
          map['tag'], // This might need TagObject.fromMap(map['tag']) if tag is also a map
      payload: map['payload'],
    );
  }
}

/// Read an annotated tag object directly
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [oid] - The SHA-1 object id to get
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<ReadTagResult>] that resolves successfully with a git object description.
/// See [ReadTagResult]
/// See [TagObject]
Future<ReadTagResult> readTag({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String oid,
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);

    // Assuming _readTag is adapted to Dart and FileSystem constructor is as well
    // And that _readTag returns a Future<Map<String, dynamic>> or Future<ReadTagResult>
    var result = await _readTag(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: effectiveGitdir,
      oid: oid,
    );

    // If _readTag returns a Map, convert it. If it returns ReadTagResult, cast or return directly.
    if (result is Map<String, dynamic>) {
      return ReadTagResult.fromMap(result);
    } else if (result is ReadTagResult) {
      return result;
    }
    // This part needs adjustment based on how _readTag is implemented in Dart
    throw UnimplementedError('_readTag result type not handled');
  } catch (e) {
    rethrow;
  }
}
