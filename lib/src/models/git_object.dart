import 'dart:typed_data';
import 'dart:convert';

import '../errors/internal_error.dart'; // Assuming InternalError is defined here

class GitObject {
  static Uint8List wrap({required String type, required Uint8List object}) {
    final header = utf8.encode('$type ${object.lengthInBytes}\x00');
    return Uint8List.fromList([...header, ...object]);
  }

  static Map<String, dynamic> unwrap(Uint8List buffer) {
    final s = buffer.indexOf(32); // first space
    final i = buffer.indexOf(0); // first null value

    if (s == -1 || i == -1) {
      throw InternalError('Invalid GitObject buffer format.');
    }

    final type = utf8.decode(buffer.sublist(0, s));
    final lengthStr = utf8.decode(buffer.sublist(s + 1, i));
    final actualLength = buffer.lengthInBytes - (i + 1);

    final expectedLength = int.tryParse(lengthStr);
    if (expectedLength == null || expectedLength != actualLength) {
      throw InternalError(
          'Length mismatch: expected $lengthStr bytes but got $actualLength instead.');
    }

    return {
      'type': type,
      'object': buffer.sublist(i + 1),
    };
  }
}