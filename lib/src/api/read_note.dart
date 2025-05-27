import 'dart:typed_data';

import '../commands/read_note.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Read the contents of a note
///
/// [fs] - a file system client
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [ref] - The notes ref to look under
/// [oid] - The SHA-1 object id of the object to get the note for.
/// [cache] - a [cache](cache.md) object
///
/// Returns a [Future<Uint8List>] that resolves successfully with note contents.
Future<Uint8List> readNote({
  required dynamic fs,
  String? dir,
  String? gitdir,
  String ref = 'refs/notes/commits',
  required String oid,
  Map<String, dynamic> cache = const {},
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('ref', ref);
    assertParameter('oid', oid);

    // Assuming _readNote is adapted to Dart and FileSystem constructor is as well
    // And that _readNote returns a Future<Uint8List>.
    return await _readNote(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: effectiveGitdir,
      ref: ref,
      oid: oid,
    );
  } catch (e) {
    rethrow;
  }
}
