import '../models/git_object.dart';
import '../utils/shasum.dart';
import 'dart:typed_data'; // For Uint8List

class HashObjectResult {
  String oid;
  Uint8List object;

  HashObjectResult({required this.oid, required this.object});
}

Future<HashObjectResult> hashObject({
  required String type,
  required Uint8List
  object, // Assuming object is Uint8List based on GitObject.wrap
  String format = 'content',
  String? currentOid, // Renamed from oid to avoid confusion, and made nullable
}) async {
  Uint8List processedObject = object;
  String resultOid;

  if (format != 'deflated') {
    if (format != 'wrapped') {
      // GitObject.wrap should be adapted to Dart. Assuming it returns Uint8List.
      processedObject = GitObject.wrap(type: type, object: object);
    }
    // shasum should be adapted to Dart. Assuming it takes Uint8List and returns Future<String>.
    resultOid = await shasum(processedObject);
  } else {
    if (currentOid == null) {
      // This case needs clarification: if format is 'deflated', an oid must be provided.
      // Throwing an error or handling it as per library's design.
      throw ArgumentError('OID must be provided if format is \'deflated\'.');
    }
    resultOid = currentOid;
  }

  return HashObjectResult(oid: resultOid, object: processedObject);
}
