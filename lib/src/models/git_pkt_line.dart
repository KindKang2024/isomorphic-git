import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// Placeholder for padHex - in a real scenario, this might come from a utility package
String _padHex(int length, int value) {
  return value.toRadixString(16).padLeft(length, '0');
}

// Placeholder for StreamReader - this is a simplified version.
// A more robust version would handle stream states, errors, and partial reads better.
class _DartStreamReader {
  final StreamIterator<Uint8List> _iterator;
  Uint8List _buffer = Uint8List(0);
  bool _streamEnded = false;

  _DartStreamReader(Stream<List<int>> stream)
    : _iterator = StreamIterator(
        stream.cast<Uint8List>(),
      ); // Assuming stream provides List<int> that are effectively Uint8List

  Future<Uint8List?> read(int numBytes) async {
    if (_streamEnded && _buffer.length < numBytes) return null;

    while (_buffer.length < numBytes) {
      if (await _iterator.moveNext()) {
        _buffer = Uint8List.fromList([..._buffer, ..._iterator.current]);
      } else {
        _streamEnded = true;
        if (_buffer.length < numBytes)
          return null; // Not enough bytes even after stream end
        break;
      }
    }

    if (_buffer.length >= numBytes) {
      final result = _buffer.sublist(0, numBytes);
      _buffer = _buffer.sublist(numBytes);
      return result;
    }
    // This case should ideally be covered by the _streamEnded check at the beginning
    // or the loop condition, but as a fallback:
    return null;
  }
}

class GitPktLine {
  static Uint8List flush() {
    return Uint8List.fromList(utf8.encode('0000'));
  }

  static Uint8List delim() {
    return Uint8List.fromList(utf8.encode('0001'));
  }

  static Uint8List encode(dynamic line) {
    Uint8List buffer;
    if (line is String) {
      buffer = Uint8List.fromList(utf8.encode(line));
    } else if (line is Uint8List) {
      buffer = line;
    } else if (line is List<int>) {
      buffer = Uint8List.fromList(line);
    } else {
      throw ArgumentError('Line must be a String, Uint8List, or List<int>');
    }

    final length = buffer.length + 4;
    final hexLength = _padHex(4, length);
    return Uint8List.fromList([...utf8.encode(hexLength), ...buffer]);
  }

  // Returns a function that mimics the JS StreamReader's read() method behavior.
  // The returned function asynchronously reads packet data from the stream.
  // It returns Uint8List for data packets, null for flush or delim packets, and throws an exception for stream errors.
  // A specific object or throwing a specific exception might be better than `true` for stream end/error.
  // For now, let's make it return `null` on stream end/error to simplify, and callers should handle that.
  static Future<Uint8List?> Function() streamReader(Stream<List<int>> stream) {
    final reader = _DartStreamReader(stream);

    return () async {
      try {
        Uint8List? lengthBytes = await reader.read(4);
        if (lengthBytes == null) return null; // End of stream or error

        String lengthHex = utf8.decode(lengthBytes);
        int length = int.parse(lengthHex, radix: 16);

        if (length == 0)
          return null; // Flush packet (0000), treat as end or special signal
        if (length == 1)
          return null; // Delim packet (0001), should not happen based on JS logic but good to be aware
        // The JS code returns `null` for length 0 and 1, which consumers like parseRefsAdResponse use to skip.

        if (length < 4) {
          // This would be an invalid packet length (e.g. 0001, 0002, 0003)
          // The original JS code handles 0 and 1, but not 2 or 3 explicitly before reading payload.
          // It might be caught by reader.read(length - 4) if length - 4 is negative or zero.
          // For robustness, we can treat these as errors or special empty packets.
          // Given the JS logic returns `null` for `length == 1` (delim), we could return `null` here too.
          // Or, more strictly, throw an error for malformed packet length.
          // Let's stick to returning null for now if it implies a skippable/non-data packet.
          // However, `length == 1` (0001) is explicitly `delim()`, usually not sent alone.
          // `length == 2` (0002) or `length == 3` (0003) are invalid pkt-line lengths.
          // The minimum valid data packet is `0004` (empty payload).
          // For now, let's assume any length < 4 that isn't 0 is an error or needs specific handling.
          // Given the js `read(length - 4)`: if length is 1,2,3, then length-4 is negative.
          // Our `_DartStreamReader.read` would likely fail or return null.
          // Let's assume for now that length < 4 (and not 0) is an error or unexpected.
          // For simplicity, and to align with JS `length == 1` returning null, we can do similar for other invalid small lengths.
          return null;
        }

        Uint8List? buffer = await reader.read(length - 4);
        if (buffer == null)
          return null; // End of stream or error during payload read

        return buffer;
      } catch (e) {
        // Rethrow or handle error appropriately. JS version sets stream.error and returns true.
        // For Dart, throwing the error or returning a specific error indicator might be better.
        // Returning null for now to signify issues or end.
        print('Error in GitPktLine.streamReader: $e');
        return null;
      }
    };
  }
}

// Placeholder for StreamReader if you need a basic one.
// A more robust solution would use existing Dart stream utilities or a dedicated library.
/*
class StreamReader {
  final StreamIterator<List<int>> _iterator;
  List<int> _buffer = [];

  StreamReader(Stream<List<int>> stream) : _iterator = StreamIterator(stream);

  Future<Uint8List?> read(int numBytes) async {
    while (_buffer.length < numBytes) {
      if (!await _iterator.moveNext()) {
        if (_buffer.isEmpty) return null; // Stream ended
        // Return what's left if not enough bytes for a full read, or handle as error
        Uint8List partial = Uint8List.fromList(_buffer);
        _buffer = [];
        return partial; 
      }
      _buffer.addAll(_iterator.current);
    }
    Uint8List result = Uint8List.fromList(_buffer.sublist(0, numBytes));
    _buffer.removeRange(0, numBytes);
    return result;
  }
}
*/
