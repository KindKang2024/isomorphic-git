import '../errors/ambiguous_error.dart';
import '../errors/not_found_error.dart';
import '../storage/expand_oid_loose.dart';
import '../storage/expand_oid_packed.dart';
import '../storage/read_object.dart' as read_object;

// Assuming fs, cache, and gitdir are available in the scope or passed differently.
// This is a placeholder for the actual implementation.
class FileSystem {}

class Cache {}

Future<String> expandOid({
  required FileSystem fs,
  required Cache cache,
  required String gitdir,
  required String oidShort,
}) async {
  // Curry the current read method so that the packfile un-deltification
  // process can acquire external ref-deltas.
  Future<dynamic> getExternalRefDelta(String oid) =>
      read_object.readObject(fs: fs, cache: cache, gitdir: gitdir, oid: oid);

  final results = await expandOidLoose(fs: fs, gitdir: gitdir, oid: oidShort);
  final packedOids = await expandOidPacked(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oidShort,
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
    throw AmbiguousError(name: 'oids', short: oidShort, matches: results);
  }
  throw NotFoundError('an object matching "$oidShort"');
}
