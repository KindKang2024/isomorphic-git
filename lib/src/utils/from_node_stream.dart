import 'dart:async';

/// Converts a Dart [Stream] to an async iterator-like interface.
class FromNodeStream<T> {
  final Stream<T> _stream;
  final List<T> _queue = [];
  bool _ended = false;
  Completer<Map<String, dynamic>>? _defer;
  late final StreamSubscription<T> _subscription;

  FromNodeStream(this._stream) {
    _subscription = _stream.listen(
      (chunk) {
        _queue.add(chunk);
        _defer?.complete({'value': _queue.removeAt(0), 'done': false});
        _defer = null;
      },
      onError: (err) {
        _defer?.completeError(err);
        _defer = null;
      },
      onDone: () {
        _ended = true;
        _defer?.complete({'done': true});
        _defer = null;
      },
    );
  }

  Future<Map<String, dynamic>> next() {
    if (_queue.isEmpty && _ended) {
      return Future.value({'done': true});
    } else if (_queue.isNotEmpty) {
      return Future.value({'value': _queue.removeAt(0), 'done': false});
    } else {
      _defer = Completer<Map<String, dynamic>>();
      return _defer!.future;
    }
  }

  void return_() {
    _subscription.cancel();
  }

  StreamIterator<T> get asyncIterator => StreamIterator(_stream);
}
