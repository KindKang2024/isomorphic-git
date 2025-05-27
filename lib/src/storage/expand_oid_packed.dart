import 'dart:io'; // For Directory, File

import '../errors/internal_error.dart';
import '../storage/read_pack_index.dart';
import '../utils/join.dart';

// Placeholder for Cache and FileSystem
class Cache {}

class FileSystem {
  Future<List<String>> readdir(String path) async {
    final dir = Directory(path);
    final entities = await dir.list().toList();
    return entities.map((e) => e.path.split('/').last).toList();
  }
}

// Placeholder for PackIndexResult, adjust based on actual readPackIndex implementation
class PackIndexResult {
  final dynamic error;
  final Map<String, dynamic> offsets; // Assuming offsets is a Map
  PackIndexResult({this.error, required this.offsets});
}

Future<List<String>> expandOidPacked({
  required FileSystem fs,
  required Cache cache,
  required String gitdir,
  required String oid,
  required Future<dynamic> Function(String) getExternalRefDelta,
}) async {
  final results = <String>[];
  final packDir = join(gitdir, 'objects/pack');
  var list = await fs.readdir(packDir);
  list = list.where((x) => x.endsWith('.idx')).toList();

  for (final filename in list) {
    final indexFile = '$gitdir/objects/pack/$filename';
    final p = await readPackIndex(
      fs: fs,
      cache: cache,
      filename: indexFile,
      getExternalRefDelta: getExternalRefDelta,
    );

    if (p.error != null) throw InternalError(p.error.toString());

    // Search through the list of oids in the packfile
    for (final keyOid in p.offsets.keys) {
      if (keyOid.startsWith(oid)) results.add(keyOid);
    }
  }
  return results;
}
