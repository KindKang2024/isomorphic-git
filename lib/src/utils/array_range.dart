// https://dev.to/namirsab/comment/2050
List<int> arrayRange(int start, int end) {
  final length = end - start;
  if (length < 0) {
    return []; // Or throw an ArgumentError, depending on desired behavior for end < start
  }
  return List<int>.generate(length, (index) => start + index);
}