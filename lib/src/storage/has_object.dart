import '../storage/has_object_loose.dart';
import '../storage/has_object_packed.dart';
import '../storage/read_object.dart' as read_object;

Future<bool> hasObject({
  required dynamic fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  String format = 'content',
}) async {
  // Curry the current read method so that the packfile un-deltification
  // process can acquire external ref-deltas.
  Future<dynamic> getExternalRefDelta(String objOid) =>
      read_object.readObject(fs: fs, cache: cache, gitdir: gitdir, oid: objOid);

  // Look for it in the loose object directory.
  bool result = await hasObjectLoose(fs: fs, gitdir: gitdir, oid: oid);
  // Check to see if it's in a packfile.
  if (!result) {
    result = await hasObjectPacked(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: oid,
      getExternalRefDelta: getExternalRefDelta,
    );
  }
  // Finally
  return result;
}
