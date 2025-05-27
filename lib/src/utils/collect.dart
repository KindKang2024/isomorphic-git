import 'dart:typed_data';

Future<Uint8List> collect(Stream<Uint8List> stream) async {
  final buffers = <Uint8List>[];
  int size = 0;

  await for (final chunk in stream) {
    buffers.add(chunk);
    size += chunk.lengthInBytes;
  }

  final result = Uint8List(size);
  int nextIndex = 0;
  for (final buffer in buffers) {
    result.setRange(nextIndex, nextIndex + buffer.lengthInBytes, buffer);
    nextIndex += buffer.lengthInBytes;
  }
  return result;
}