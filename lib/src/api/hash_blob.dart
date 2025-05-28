import '../static_typedefs.dart';
import '../utils/assert_parameter.dart';
import '../utils/hash_object.dart';

/// Hash a blob object
///
/// [object] - The blob content to hash
///
/// Returns the SHA-1 hash of the blob
Future<String> hashBlob({
  required dynamic object,
}) async {
  try {
    assertParameter('object', object);
    
    return await hashObject(
      type: 'blob',
      object: object,
    );
  } catch (err) {
    rethrow;
  }
}