import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p; // For path joining

import '../errors/internal_error.dart';
import '../models/git_object.dart'; // Assuming GitObject has a structure for the result
import '../models/file_system.dart'; // Assuming a file system shim for 'fs'
import 'read_pack_index.dart';

// Define a class or typedef for the result if not already covered by GitObject
// For example:
class ReadObjectPackedResult {
  final String format;
  final Uint8List object;
  final String? type; // type might not always be present initially
  final String source;

  ReadObjectPackedResult({
    required this.format,
    required this.object,
    this.type,
    required this.source,
  });
}

Future<ReadObjectPackedResult?> readObjectPacked({
  required FileSystem fs,
  // cache is not directly used here as readPackIndex handles its own caching
  required String gitdir,
  required String oid,
  // format = 'content' is the default and only supported format by the original JS for packed objects
  required Future<Uint8List> Function(String oid) getExternalRefDelta,
}) async {
  final packDir = p.join(gitdir, 'objects', 'pack');
  List<String> list;
  try {
    list = await fs.readdir(packDir);
  } catch (e) {
    // Directory might not exist or other fs error
    return null;
  }

  list = list.where((x) => x.endsWith('.idx')).toList();

  for (final filename in list) {
    final indexFile = p.join(packDir, filename);
    final packIndex = await readPackIndex(
      fs: fs,
      filename: indexFile,
      getExternalRefDelta: getExternalRefDelta,
    );

    if (packIndex == null) {
      // Couldn't load this pack index, try next
      continue;
    }
    // In JS, p.error was checked. Assuming GitPackIndex.fromIdx or readPackIndex would throw on critical errors.

    if (packIndex.offsets.containsKey(oid)) {
      // Get the resolved git object from the packfile
      if (packIndex.packData == null) {
        final packFile = indexFile.replaceAll(RegExp(r'\.idx$'), '.pack');
        final packData = await fs.read(packFile);
        if (packData == null) {
          throw InternalError('Packfile $packFile not found for index $indexFile');
        }
        packIndex.packData = Future.value(packData);
      }

      // Assuming packIndex.read() is the method to get the object data
      // The return type of packIndex.read() needs to align with GitObject or a similar structure.
      // For this translation, let's assume it returns a map or an object with 'type' and 'object' (Uint8List).
      final resultData = await packIndex.read(oid: oid, getExternalRefDelta: getExternalRefDelta);
      
      return ReadObjectPackedResult(
        format: 'content', // Packed objects are always returned as 'content'
        object: resultData['object'] as Uint8List,
        type: resultData['type'] as String?,
        source: p.join('objects', 'pack', filename.replaceAll(RegExp(r'\.idx$'), '.pack')),
      );
    }
  }
  return null; // Failed to find it
}