import 'dart:async';

/// Converts a value to an async iterator-like interface.
class FromValue<T> {
  final List<T> _queue;

  FromValue(T value) : _queue = [value];

  Future<Map<String, dynamic>> next() async {
    final done = _queue.isEmpty;
    final value = done ? null : _queue.removeLast();
    return {'done': done, 'value': value};
  }

  void return_() {
    _queue.clear();
  }

  Stream<T> get stream async* {
    if (_queue.isNotEmpty) {
      yield _queue.removeLast();
    }
  }
}
