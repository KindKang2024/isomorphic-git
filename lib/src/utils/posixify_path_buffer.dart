import 'dart:typed_data';

Uint8List posixifyPathBuffer(Uint8List buffer) {
  for (var i = 0; i < buffer.length; i++) {
    if (buffer[i] == 92) buffer[i] = 47;
  }
  return buffer;
}
