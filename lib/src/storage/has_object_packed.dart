import '../errors/internal_error.dart';
import '../storage/read_pack_index.dart';
import '../utils/join.dart';

Future<bool> hasObjectPacked({
  required dynamic fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  required Future<dynamic> Function(String) getExternalRefDelta,
}) async {
  // Check to see if it's in a packfile.
  // Iterate through all the .idx files
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
    // If the packfile DOES have the oid we're looking for...
    if (p.offsets.containsKey(oid)) {
      return true;
    }
  }
  // Failed to find it
  return false;
}
