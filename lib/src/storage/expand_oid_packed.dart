import 'package:isomorphic_git/src/storage/expand_oid_loose.dart';

import '../errors/internal_error.dart';
import '../storage/read_pack_index.dart';
import '../utils/join.dart';

Future<List<String>> expandOidPacked({
  required FileSystem fs,
  required Map<String,dynamic> cache,
  required String gitdir,
  required String oid,
  required Future<dynamic> Function(String) getExternalRefDelta,
}) async {
  // Iterate through all the .pack files
  final results = <String>[];
  List<String> list = await fs.readdir(join(gitdir, 'objects/pack'));
  list = list.where((x) => x.endsWith('.idx')).toList();
  for (final filename in list) {
    final indexFile = '$gitdir/objects/pack/$filename';
    final p = await readPackIndex(
      fs: fs,
      cache: cache,
      filename: indexFile,
      getExternalRefDelta: getExternalRefDelta,
    );
    if (p.error != null) throw InternalError(p.error!);
    // Search through the list of oids in the packfile
    for (final packOid in p.offsets.keys) {
      if (packOid.startsWith(oid)) results.add(packOid);
    }
  }
  return results;
}
