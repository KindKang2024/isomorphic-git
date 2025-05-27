import 'dart:async';

/// Converts a Dart [Stream] to an async iterator-like interface.
class FromStream<T> {
  final Stream<T> _stream;
  late final StreamIterator<T> _iterator;

  FromStream(this._stream) {
    _iterator = StreamIterator(_stream);
  }

  Future<Map<String, dynamic>> next() async {
    final hasNext = await _iterator.moveNext();
    if (hasNext) {
      return {'value': _iterator.current, 'done': false};
    } else {
      return {'done': true};
    }
  }

  void return_() {
    _iterator.cancel();
  }

  StreamIterator<T> get asyncIterator => _iterator;
}
