import '../commands/read_tree.dart';
import '../models/file_system.dart';
import '../models/tree_object.dart'; // Assuming this is the Dart equivalent of TreeObject
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

class ReadTreeResult {
  String oid; // SHA-1 object id of this tree
  TreeObject tree; // the parsed tree object

  ReadTreeResult({required this.oid, required this.tree});

  // Optional: Factory constructor if _readTree returns a map
  factory ReadTreeResult.fromMap(Map<String, dynamic> map) {
    return ReadTreeResult(
      oid: map['oid'],
      // This might need TreeObject.fromMap(map['tree']) if tree is also a map from _readTree
      tree: map['tree'] is TreeObject
          ? map['tree']
          : TreeObject.fromEntries(map['tree']),
    );
  }
}

/// Read a tree object directly
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [oid] - The SHA-1 object id to get. Annotated tags and commits are peeled.
/// [filepath] - Don't return the object with `oid` itself, but resolve `oid` to a tree and then return the tree object at that filepath.
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<ReadTreeResult>] that resolves successfully with a git tree object.
/// See [ReadTreeResult]
/// See [TreeObject]
/// See [TreeEntry] // Assuming TreeEntry is part of TreeObject or a separate model
Future<ReadTreeResult> readTree({
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

    // Assuming _readTree is adapted to Dart and FileSystem constructor is as well
    // And that _readTree returns a Future<Map<String, dynamic>> or Future<ReadTreeResult>
    var result = await _readTree(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: effectiveGitdir,
      oid: oid,
      filepath: filepath,
    );

    // If _readTree returns a Map, convert it. If it returns ReadTreeResult, cast or return directly.
    if (result is Map<String, dynamic>) {
      return ReadTreeResult.fromMap(result);
    } else if (result is ReadTreeResult) {
      return result;
    }
    // This part needs adjustment based on how _readTree is implemented in Dart
    throw UnimplementedError(
      '_readTree result type not handled: ${result.runtimeType}',
    );
  } catch (e) {
    rethrow;
  }
}
