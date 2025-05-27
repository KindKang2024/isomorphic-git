import 'dart:typed_data';

/// Determine whether a file is binary (not worth trying to merge automatically)
bool isBinary(Uint8List buffer) {
  const int MAX_XDIFF_SIZE = 1024 * 1024 * 1023;
  if (buffer.length > MAX_XDIFF_SIZE) return true;
  // Check for null characters in the first 8000 bytes
  final end = buffer.length < 8000 ? buffer.length : 8000;
  for (int i = 0; i < end; i++) {
    if (buffer[i] == 0) return true;
  }
  return false;
}
