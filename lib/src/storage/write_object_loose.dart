import 'dart:typed_data';

import '../utils/fs.dart'; // Assuming FileSystem is defined here
// Assuming InternalError is defined in a similar location or needs to be created.
// import '../errors/internal_error.dart';

// Placeholder for InternalError if not defined elsewhere
class InternalError extends Error {
  final String message;
  InternalError(this.message);
  @override
  String toString() => 'InternalError: $message';
}

Future<void> writeObjectLoose({
  required FileSystem fs,
  required String gitdir,
  required Uint8List object,
  required String format,
  required String?
  oid, // oid can be null if not provided, though original implies it's required
}) async {
  if (format != 'deflated') {
    throw InternalError(
      'GitObjectStoreLoose expects objects to write to be in deflated format',
    );
  }
  if (oid == null) {
    // Or handle this as an error, as the original JS seems to expect oid to be always present.
    throw InternalError('OID cannot be null when writing loose object');
  }
  final String source = 'objects/${oid.substring(0, 2)}/${oid.substring(2)}';
  final String filepath = '$gitdir/$source';

  // Don't overwrite existing git objects - this helps avoid EPERM errors.
  // Although I don't know how we'd fix corrupted objects then. Perhaps delete them
  // on read?
  if (!(await fs.exists(filepath))) {
    await fs.write(filepath, object);
  }
}
