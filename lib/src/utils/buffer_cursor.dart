import 'dart:typed_data';
import 'dart:convert';

// Modeled after https://github.com/tjfontaine/node-buffercursor
// but with the goal of being much lighter weight.
class BufferCursor {
  final Uint8List _buffer;
  int _start = 0;
  final ByteData _byteDataView;

  BufferCursor(Uint8List buffer)
    : _buffer = buffer,
      _byteDataView = ByteData.view(
        buffer.buffer,
        buffer.offsetInBytes,
        buffer.lengthInBytes,
      );

  bool eof() {
    return _start >= _buffer.lengthInBytes;
  }

  int tell() {
    return _start;
  }

  void seek(int n) {
    if (n < 0 || n > _buffer.lengthInBytes) {
      throw RangeError('Seek position is out of bounds');
    }
    _start = n;
  }

  Uint8List slice(int n) {
    if (_start + n > _buffer.lengthInBytes) {
      throw RangeError('Slice length is out of bounds');
    }
    final r = Uint8List.view(_buffer.buffer, _buffer.offsetInBytes + _start, n);
    _start += n;
    return r;
  }

  String toStringFromUtf8(int length) {
    if (_start + length > _buffer.lengthInBytes) {
      throw RangeError('Length for toString is out of bounds');
    }
    final r = utf8.decode(_buffer.sublist(_start, _start + length));
    _start += length;
    return r;
  }

  // Note: Dart's Uint8List doesn't have a direct 'write' string method like Node's Buffer.
  // This typically involves encoding the string to bytes first.
  // This example assumes UTF-8 encoding.
  int writeStringAsUtf8(String value) {
    final bytesToWrite = utf8.encode(value);
    if (_start + bytesToWrite.length > _buffer.lengthInBytes) {
      throw RangeError('Not enough space to write string');
    }
    _buffer.setRange(_start, _start + bytesToWrite.length, bytesToWrite);
    final bytesWritten = bytesToWrite.length;
    _start += bytesWritten;
    return bytesWritten;
  }

  int copy(Uint8List source, int sourceStart, int sourceEnd) {
    final lengthToCopy = sourceEnd - sourceStart;
    if (lengthToCopy < 0) {
      throw ArgumentError(
        'sourceEnd must be greater than or equal to sourceStart',
      );
    }
    if (_start + lengthToCopy > _buffer.lengthInBytes) {
      throw RangeError('Not enough space in target buffer');
    }
    if (sourceStart < 0 ||
        sourceEnd > source.lengthInBytes ||
        sourceStart > sourceEnd) {
      throw RangeError('Source range is out of bounds');
    }
    _buffer.setRange(_start, _start + lengthToCopy, source, sourceStart);
    _start += lengthToCopy;
    return lengthToCopy;
  }

  int readUint8() {
    if (_start + 1 > _buffer.lengthInBytes) {
      throw RangeError('Read out of bounds');
    }
    final r = _byteDataView.getUint8(_start);
    _start += 1;
    return r;
  }

  void writeUint8(int value) {
    if (_start + 1 > _buffer.lengthInBytes) {
      throw RangeError('Write out of bounds');
    }
    _byteDataView.setUint8(_start, value);
    _start += 1;
  }

  int readUint16BE() {
    if (_start + 2 > _buffer.lengthInBytes) {
      throw RangeError('Read out of bounds');
    }
    final r = _byteDataView.getUint16(_start, Endian.big);
    _start += 2;
    return r;
  }

  void writeUint16BE(int value) {
    if (_start + 2 > _buffer.lengthInBytes) {
      throw RangeError('Write out of bounds');
    }
    _byteDataView.setUint16(_start, value, Endian.big);
    _start += 2;
  }

  int readUint32BE() {
    if (_start + 4 > _buffer.lengthInBytes) {
      throw RangeError('Read out of bounds');
    }
    final r = _byteDataView.getUint32(_start, Endian.big);
    _start += 4;
    return r;
  }

  void writeUint32BE(int value) {
    if (_start + 4 > _buffer.lengthInBytes) {
      throw RangeError('Write out of bounds');
    }
    _byteDataView.setUint32(_start, value, Endian.big);
    _start += 4;
  }
}
