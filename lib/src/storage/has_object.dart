import '../storage/has_object_loose.dart';
import '../storage/has_object_packed.dart';
import '../storage/read_object.dart' as read_object;

// Placeholders for FileSystem and Cache
class FileSystem {}

class Cache {}

Future<bool> hasObject({
  required FileSystem fs,
  required Cache cache,
  required String gitdir,
  required String oid,
  String format =
      'content', // Dart doesn't directly support default values for named params like this in older versions, ensure compatibility or adjust.
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
