import 'async_iterator_to_stream.dart';

Future<void> forAwait<T>(dynamic iterable, Future<void> Function(T) cb) async {
  final iterator = getIterator<T>(iterable);
  while (true) {
    final next = await iterator.next();
    if (next.value != null) await cb(next.value as T);
    if (next.done) break;
  }
  if (iterator.return_ != null) iterator.return_!();
}
