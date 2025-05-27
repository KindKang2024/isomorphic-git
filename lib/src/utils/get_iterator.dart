import 'from_value.dart';

/// Returns an iterator for the given [iterable].
dynamic getIterator(dynamic iterable) {
  if (iterable is Stream) {
    return StreamIterator(iterable);
  }
  if (iterable is Iterable) {
    return iterable.iterator;
  }
  if (iterable is Iterator) {
    return iterable;
  }
  return FromValue(iterable);
}
