import 'dart:typed_data';
import '../errors/internal_error.dart';
import 'buffer_cursor.dart';

Uint8List applyDelta(Uint8List delta, Uint8List source) {
  final reader = BufferCursor(delta);
  final sourceSize = _readVarIntLE(reader);

  if (sourceSize != source.lengthInBytes) {
    throw InternalError(
        'applyDelta expected source buffer to be $sourceSize bytes but the provided buffer was ${source.lengthInBytes} bytes');
  }
  final targetSize = _readVarIntLE(reader);
  Uint8List target;

  final firstOp = _readOp(reader, source);
  // Speed optimization - return raw buffer if it's just single simple copy
  if (firstOp.lengthInBytes == targetSize) {
    target = firstOp;
  } else {
    // Otherwise, allocate a fresh buffer and slices
    target = Uint8List(targetSize);
    // Simulating writer.copy(firstOp) behavior:
    BufferCursor.writeBytesTo(target, 0, firstOp);
    int currentTargetOffset = firstOp.lengthInBytes;

    while (!reader.eof()) {
      final opData = _readOp(reader, source);
      BufferCursor.writeBytesTo(target, currentTargetOffset, opData);
      currentTargetOffset += opData.lengthInBytes;
    }

    if (targetSize != currentTargetOffset) {
      throw InternalError(
          'applyDelta expected target buffer to be $targetSize bytes but the resulting buffer was $currentTargetOffset bytes');
    }
  }
  return target;
}

int _readVarIntLE(BufferCursor reader) {
  int result = 0;
  int shift = 0;
  int byte;
  do {
    byte = reader.readUInt8();
    result |= (byte & 0x7F) << shift;
    shift += 7;
  } while ((byte & 0x80) != 0);
  return result;
}

int _readCompactLE(BufferCursor reader, int flags, int size) {
  int result = 0;
  int shift = 0;
  while (size-- > 0) {
    if ((flags & 0x01) != 0) {
      result |= reader.readUInt8() << shift;
    }
    flags >>= 1;
    shift += 8;
  }
  return result;
}

Uint8List _readOp(BufferCursor reader, Uint8List source) {
  final byte = reader.readUInt8();
  const int COPY = 0x80;
  const int OFFS_MASK = 0x0F; // Mask for offset flags
  const int SIZE_SHIFT = 4; // Shift for size flags
  const int SIZE_MASK = 0x07; // Mask for size flags (0b0111 after shift)

  if ((byte & COPY) != 0) {
    // copy consists of 4 byte offset, 3 byte size (in LE order)
    final offsetFlags = byte & OFFS_MASK;
    final sizeFlags = (byte >> SIZE_SHIFT) & SIZE_MASK;

    final offset = _readCompactLE(reader, offsetFlags, 4);
    int size = _readCompactLE(reader, sizeFlags, 3);
    
    // Yup. They really did this optimization.
    if (size == 0) size = 0x10000;
    
    // Ensure offset and size are within bounds of the source buffer
    if (offset + size > source.lengthInBytes) {
        throw InternalError('Delta copy operation is out of bounds for source buffer. Offset: $offset, Size: $size, Source Length: ${source.lengthInBytes}');
    }
    return Uint8List.sublistView(source, offset, offset + size);
  } else {
    // insert: 'byte' is the length of data to read directly from delta
    if (byte == 0) { // Should not happen based on typical delta encoding, but good to guard
        return Uint8List(0);
    }
    return reader.slice(byte);
  }
}