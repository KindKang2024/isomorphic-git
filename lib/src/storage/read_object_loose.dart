import 'dart:typed_data'; // For Uint8List
import 'dart:io';

import 'package:isomorphic_git/src/models/file_system.dart'; // For File, FileSystemException


class ReadObjectLooseResult {
  final Uint8List object;
  final String format;
  final String?
  source; // source is not strictly needed by readObject, but kept for parity

  ReadObjectLooseResult({
    required this.object,
    required this.format,
    this.source,
  });
}

Future<ReadObjectLooseResult?> readObjectLoose({
  required FileSystem fs,
  required String gitdir,
  required String oid,
}) async {
  final sourcePath = 'objects/${oid.substring(0, 2)}/${oid.substring(2)}';
  final fullPath = '$gitdir/$sourcePath';

  final Uint8List? fileContent = await fs.read(fullPath);

  if (fileContent == null) {
    return null;
  }

  // In the original JS, `source` was just the relative path part.
  // We pass it along, though `readObject` in Dart doesn't use it from this result.
  return ReadObjectLooseResult(
    object: fileContent,
    format: 'deflated',
    source: sourcePath,
  );
}
