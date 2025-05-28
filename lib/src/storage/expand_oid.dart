import '../errors/ambiguous_error.dart';
import '../errors/not_found_error.dart';
import '../storage/expand_oid_loose.dart';
import '../storage/expand_oid_packed.dart';
import '../storage/read_object.dart' as read_object;

Future<String> expandOid({
  required dynamic fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
}) async {
  // Curry the current read method so that the packfile un-deltification
  // process can acquire external ref-deltas.
  Future<dynamic> getExternalRefDelta(String objOid) =>
      read_object.readObject(fs: fs, cache: cache, gitdir: gitdir, oid: objOid);

  final results = await expandOidLoose(fs: fs, gitdir: gitdir, oid: oid);
  final packedOids = await expandOidPacked(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
    getExternalRefDelta: getExternalRefDelta,
  );

  // Objects can exist in a pack file as well as loose, make sure we only get a list of unique oids.
  for (final packedOid in packedOids) {
    if (!results.contains(packedOid)) {
      results.add(packedOid);
    }
  }

  if (results.length == 1) {
    return results[0];
  }
  if (results.length > 1) {
    throw AmbiguousError(name: 'oids', value: oid, possibilities: results);
  }
  throw NotFoundError(thing: 'an object matching "$oid"');
}
