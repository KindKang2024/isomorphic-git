import 'dart:typed_data';

import '../utils/resolve_blob.dart';
import '../utils/resolve_filepath.dart';

// TODO: Define these types or import them
typedef FileSystem = dynamic; // Placeholder
typedef Cache = dynamic; // Placeholder

class ReadBlobResult {
  final String oid;
  final Uint8List blob;

  ReadBlobResult({required this.oid, required this.blob});
}

Future<ReadBlobResult> readBlob({
  required FileSystem fs,
  required Cache cache,
  required String gitdir,
  required String oid,
  String? filepath,
}) async {
  String currentOid = oid;
  if (filepath != null) {
    currentOid = await resolveFilepath(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: currentOid,
      filepath: filepath,
    );
  }

  // resolveBlob in JS returns { oid, blob }
  // Assuming resolveBlob in Dart will return a similar structure or a ReadBlobResult directly.
  // For now, let's assume it returns a map that we convert.
  final result = await resolveBlob(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: currentOid,
  );

  // If resolveBlob already returns ReadBlobResult, this explicit construction is not needed.
  // Otherwise, adapt based on what resolveBlob actually returns.
  if (result is ReadBlobResult) {
    return result;
  } else if (result is Map) {
    return ReadBlobResult(oid: result['oid'], blob: result['blob']);
  }
  // Add more robust error handling or type checking if necessary
  throw Exception('resolveBlob returned an unexpected type');
}
