import 'dart:io';
import 'dart:typed_data';

import '../commands/pack.dart';
import '../utils/collect.dart';
import 'package:path/path.dart' as p;

class PackObjectsResult {
  final String filename;
  final Uint8List? packfile;

  PackObjectsResult({required this.filename, this.packfile});
}

Future<PackObjectsResult> packObjects({
  required Directory fs,
  required dynamic cache,
  required String gitdir,
  required List<String> oids,
  bool write = false,
}) async {
  final buffers = await pack(fs: fs, cache: cache, gitdir: gitdir, oids: oids);
  final packfileBytes = await collect(buffers);

  // Get the SHA from the last 20 bytes
  final packfileSha = packfileBytes
      .sublist(packfileBytes.length - 20)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  final filename = 'pack-$packfileSha.pack';

  if (write) {
    final filePath = p.join(gitdir, 'objects', 'pack', filename);
    await File(filePath).writeAsBytes(packfileBytes, flush: true);
    return PackObjectsResult(filename: filename);
  } else {
    return PackObjectsResult(filename: filename, packfile: packfileBytes);
  }
}
