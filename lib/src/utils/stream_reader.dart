import 'dart:async';
import 'dart:typed_data';

// Helper to convert Stream<List<int>> to an asynchronous iterator like interface
// This is a simplified conceptual mapping. Dart's Stream API is typically used directly.
class _StreamIterator {
  final StreamIterator<Uint8List> _iterator;
  bool _hasError = false;
  dynamic _error;

  _StreamIterator(Stream<Uint8List> stream) : _iterator = StreamIterator(stream);

  Future<({bool done, Uint8List? value})> next() async {
    if (_hasError) throw _error;
    try {
      if (await _iterator.moveNext()) {
        return (done: false, value: _iterator.current);
      }
      return (done: true, value: null);
    } catch (e) {
      _hasError = true;
      _error = e;
      rethrow;
    }
  }
}

class StreamReader {
  final _StreamIterator _streamIterator;
  Uint8List _buffer = Uint8List(0);
  int _cursor = 0;
  int _undoCursor = 0;
  bool _started = false;
  bool _ended = false;
  int _discardedBytes = 0;

  StreamReader(Stream<Uint8List> stream) : _streamIterator = _StreamIterator(stream);

  bool eof() {
    return _ended && _cursor == _buffer.length;
  }

  int tell() {
    return _discardedBytes + _cursor;
  }

  Future<int?> byte() async {
    if (eof()) return null;
    if (!_started) await _init();
    if (_cursor == _buffer.length) {
      await _loadNext();
      if (_ended && _cursor == _buffer.length) return null; // Check again after loadNext
    }
    _moveCursor(1);
    return _buffer[_undoCursor];
  }

  Future<Uint8List?> chunk() async {
    if (eof()) return null;
    if (!_started) await _init();
    if (_cursor == _buffer.length) {
      await _loadNext();
       if (_ended && _cursor == _buffer.length) return null; // Check again after loadNext
    }
    _moveCursor(_buffer.length - _cursor); // Read the rest of the current buffer
    return Uint8List.view(_buffer.buffer, _buffer.offsetInBytes + _undoCursor, _cursor - _undoCursor);
  }

  Future<Uint8List?> read(int n) async {
    if (n == 0) return Uint8List(0);
    if (eof()) return null;
    if (!_started) await _init();

    if (_cursor + n > _buffer.length) {
      _trim();
      await _accumulate(n);
    }
    // If still not enough bytes after accumulate (stream ended prematurely)
    if (_cursor + n > _buffer.length) {
      n = _buffer.length - _cursor; // Read what's available
    }
    if (n <= 0 && _ended) return null; // Nothing more to read
    if (n <=0 && !_ended) return Uint8List(0); // Requesting 0 or negative bytes

    _moveCursor(n);
    return Uint8List.view(_buffer.buffer, _buffer.offsetInBytes + _undoCursor, n);
  }

  Future<void> skip(int n) async {
    if (n == 0) return;
    if (eof()) return;
    if (!_started) await _init();

    if (_cursor + n > _buffer.length) {
      _trim();
      await _accumulate(n);
    }
    _moveCursor(n);
  }

  void undo() {
    _cursor = _undoCursor;
  }

  Future<Uint8List> _nextChunk() async {
    _started = true;
    final result = await _streamIterator.next();
    if (result.done) {
      _ended = true;
      return result.value ?? Uint8List(0); // Ensure non-null for ended stream
    }
    return result.value ?? Uint8List(0); // Should have value if not done
  }

  void _trim() {
    if (_undoCursor > 0 && _buffer.isNotEmpty) {
        _buffer = Uint8List.fromList(_buffer.sublist(_undoCursor));
    }
    _cursor -= _undoCursor;
    _discardedBytes += _undoCursor;
    _undoCursor = 0;
  }

  void _moveCursor(int n) {
    _undoCursor = _cursor;
    _cursor += n;
    if (_cursor > _buffer.length) {
      _cursor = _buffer.length;
    }
  }

  Future<void> _accumulate(int n) async {
    if (_ended) return;
    final List<Uint8List> buffers = [_buffer];
    while (_currentBufferLength(buffers) < n) {
      final nextBufferChunk = await _nextChunk();
      if (_ended && nextBufferChunk.isEmpty) break;
      buffers.add(nextBufferChunk);
      if (_ended) break; // Break if stream ended during accumulation
    }
    _buffer = _concatenateBuffers(buffers);
  }

  int _currentBufferLength(List<Uint8List> buffers) {
     return buffers.fold(0, (prev, buf) => prev + buf.length) - _cursor;
  }

  Uint8List _concatenateBuffers(List<Uint8List> buffers) {
    final totalLength = buffers.fold(0, (sum, buf) => sum + buf.length);
    final result = Uint8List(totalLength);
    int offset = 0;
    for (final buf in buffers) {
      result.setRange(offset, offset + buf.length, buf);
      offset += buf.length;
    }
    return result;
  }

  Future<void> _loadNext() async {
    _discardedBytes += _buffer.length;
    _undoCursor = 0;
    _cursor = 0;
    _buffer = await _nextChunk();
  }

  Future<void> _init() async {
    _buffer = await _nextChunk();
  }
}