import 'dart:typed_data';

String toHex(Uint8List buffer) {
  final hexChars = StringBuffer();
  for (final byte in buffer) {
    hexChars.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return hexChars.toString();
}
