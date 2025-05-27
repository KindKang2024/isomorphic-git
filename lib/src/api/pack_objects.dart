import 'dart:typed_data';

import '../commands/pack_objects.dart' as commands;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

class PackObjectsResult {
  final String filename;
  final Uint8List? packfile;

  PackObjectsResult({required this.filename, this.packfile});

  factory PackObjectsResult.fromMap(Map<String, dynamic> map) {
    return PackObjectsResult(
      filename: map['filename'],
      packfile: map['packfile'],
    );
  }
}

/// Create a packfile from an array of SHA-1 object ids
Future<PackObjectsResult> packObjects({
  required FileSystem fs,
  String? dir,
  String? gitdir,
  required List<String> oids,
  bool write = false,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('oids', oids);

    var result = await commands.packObjects(
      fs: FileSystem(fs.client),
      cache: cache,
      gitdir: gitdir,
      oids: oids,
      write: write,
    );
    return PackObjectsResult.fromMap(result);
  } catch (err) {
    //TODO: err.caller = 'git.packObjects';
    rethrow;
  }
}
