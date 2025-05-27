import 'dart:convert'; // For utf8.encode
import 'dart:typed_data'; // For Uint8List

import '../storage/hash_object.dart' as storage_hash_object;
import '../utils/assert_parameter.dart';

class HashBlobResult {
  final String oid; // The SHA-1 object id
  final String type; // Should always be 'blob'
  final Uint8List object; // The wrapped git object (the thing that is hashed)
  final String format; // Should always be 'wrapped'

  HashBlobResult({
    required this.oid,
    required this.type,
    required this.object,
    required this.format,
  });

  Map<String, dynamic> toJson() => {
    'oid': oid,
    'type': type,
    'object':
        object, // Uint8List will likely be base64 encoded by jsonEncode if not handled
    'format': format,
  };
}

Future<HashBlobResult> hashBlob({
  required dynamic object, // Can be String or Uint8List
}) async {
  try {
    assertParameter('object', object);

    Uint8List objectData;
    if (object is String) {
      objectData = utf8.encode(object);
    } else if (object is Uint8List) {
      objectData = object;
    } else if (object is List<int>) {
      // Allow List<int> as well, convert to Uint8List
      objectData = Uint8List.fromList(object);
    } else {
      throw ArgumentError('object must be a String, Uint8List, or List<int>');
    }

    final String type = 'blob';

    // Assuming storage_hash_object.hashObject returns a map or an object
    // with 'oid' and 'object' (the wrapped object) fields.
    final hashResult = await storage_hash_object.hashObject(
      type: 'blob',
      format: 'content', // This is what's passed to the internal hasher
      object: objectData,
    );

    // The JS code implies hashObject returns {oid, object: _object}
    // where _object is the raw wrapped content.
    // We need to ensure hashResult from Dart's hashObject has these fields.
    // And the returned object field in HashBlobResult should be this wrapped content.

    // Assuming hashResult is a Map<String, dynamic> or a custom class
    String resultOid;
    Uint8List resultObjectData;

    if (hashResult is Map) {
      resultOid = hashResult['oid'] as String;
      // The internal _object from JS hashObject is the wrapped content.
      // Ensure the Dart hashObject provides this.
      var internalObject = hashResult['object'];
      if (internalObject is Uint8List) {
        resultObjectData = internalObject;
      } else if (internalObject is List<int>) {
        resultObjectData = Uint8List.fromList(internalObject);
      } else {
        throw StateError(
          'hashObject did not return a valid object field for wrapping',
        );
      }
    } else {
      // If hashObject returns a custom class, access properties directly, e.g.:
      // resultOid = hashResult.oid;
      // resultObjectData = hashResult.object;
      // This depends on the definition of your Dart hashObject function.
      throw StateError(
        'Unexpected return type from storage_hash_object.hashObject',
      );
    }

    return HashBlobResult(
      oid: resultOid,
      type: type,
      object:
          resultObjectData, // This is the wrapped object, as per JS `new Uint8Array(_object)`
      format:
          'wrapped', // This indicates the format of the HashBlobResult.object field
    );
  } catch (err) {
    // err.caller = 'git.hashBlob' // Custom error handling needed for this property
    rethrow;
  }
}
