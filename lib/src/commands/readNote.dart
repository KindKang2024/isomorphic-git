import 'dart:typed_data';

import '../managers/git_ref_manager.dart';
import './read_blob.dart';

/// Read the contents of a note
///
/// [fs]: FileSystem
/// [cache]: any
/// [gitdir]: string
/// [ref]: The notes ref to look under
/// [oid]: string
///
/// Returns a Future that resolves successfully with note contents as a Uint8List.
Future<Uint8List> readNote({
  required fs,
  required cache,
  required String gitdir,
  String ref = 'refs/notes/commits',
  required String oid,
}) async {
  final parent = await GitRefManager.resolve(gitdir: gitdir, fs: fs, ref: ref);
  final blobResult = await readBlob(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: parent,
    filepath: oid,
  );

  return blobResult.blob;
}
