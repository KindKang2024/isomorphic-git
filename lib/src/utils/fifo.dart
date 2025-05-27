import 'dart:async';

class Fifo<T> {
  final _queue = <T>[];
  bool _ended = false;
  Completer<({T? value, bool done})>? _waitingCompleter;
  Object? error;

  void write(T chunk) {
    if (_ended) {
      throw StateError('You cannot write to a FIFO that has already been ended!');
    }
    if (_waitingCompleter != null) {
      final completer = _waitingCompleter!;
      _waitingCompleter = null;
      completer.complete((value: chunk, done: false));
    } else {
      _queue.add(chunk);
    }
  }

  void end() {
    _ended = true;
    if (_waitingCompleter != null) {
      final completer = _waitingCompleter!;
      _waitingCompleter = null;
      completer.complete((value: null, done: true));
    }
  }

  void destroy(Object err) {
    error = err;
    end();
  }

  Future<({T? value, bool done})> next() async {
    if (error != null) {
      throw error!;
    }
    if (_queue.isNotEmpty) {
      return (value: _queue.removeAt(0), done: false);
    }
    if (_ended) {
      return (value: null, done: true);
    }
    if (_waitingCompleter != null) {
      throw StateError('You cannot call read until the previous call to read has returned!');
    }
    _waitingCompleter = Completer<({T? value, bool done})>();
    return _waitingCompleter!.future;
  }

  // Helper to use FIFO as an AsyncIterator (Stream in Dart)
  Stream<T> asStream() async* {
    while (true) {
      final result = await next();
      if (result.done) {
        break;
      }
      yield result.value as T;
    }
  }
}