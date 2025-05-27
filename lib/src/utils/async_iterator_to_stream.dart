import 'dart:async';
import 'package:async/async.dart';

/// Converts an async iterator (Stream or Iterable) to a Stream.
Stream<T> asyncIteratorToStream<T>(dynamic iter) {
  final controller = StreamController<T>();
  Future(() async {
    await forAwait<T>(iter, (chunk) => controller.sink.add(chunk));
    await controller.close();
  });
  return controller.stream;
}

/// Helper to handle both Stream and Iterable as async iterators.
Future<void> forAwait<T>(
  dynamic iterable,
  FutureOr<void> Function(T) cb,
) async {
  final iterator = getIterator<T>(iterable);
  while (true) {
    final next = await iterator.next();
    if (next.value != null) await cb(next.value as T);
    if (next.done) break;
  }
  if (iterator.return_ != null) iterator.return_!();
}

/// Dart equivalent of JS iterator protocol.
class AsyncIterator<T> {
  final FutureOr<NextResult<T>> Function() next;
  final void Function()? return_;
  AsyncIterator({required this.next, this.return_});
}

class NextResult<T> {
  final bool done;
  final T? value;
  NextResult({required this.done, this.value});
}

AsyncIterator<T> getIterator<T>(dynamic iterable) {
  if (iterable is Stream<T>) {
    final queue = StreamQueue<T>(iterable);
    return AsyncIterator<T>(
      next: () async {
        final hasNext = await queue.hasNext;
        return NextResult<T>(
          done: !hasNext,
          value: hasNext ? await queue.next : null,
        );
      },
      return_: () async {
        await queue.cancel();
      },
    );
  }
  if (iterable is Iterable<T>) {
    final it = iterable.iterator;
    return AsyncIterator<T>(
      next: () async {
        final hasNext = it.moveNext();
        return NextResult<T>(
          done: !hasNext,
          value: hasNext ? it.current : null,
        );
      },
      return_: () {},
    );
  }
  if (iterable is AsyncIterator<T>) {
    return iterable;
  }
  return fromValue<T>(iterable);
}

AsyncIterator<T> fromValue<T>(T value) {
  List<T> queue = [value];
  return AsyncIterator<T>(
    next: () async {
      return NextResult<T>(
        done: queue.isEmpty,
        value: queue.isNotEmpty ? queue.removeLast() : null,
      );
    },
    return_: () {
      queue.clear();
    },
  );
}
