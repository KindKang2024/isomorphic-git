String padHex(int b, int n) {
  final s = n.toRadixString(16);
  return '0' * (b - s.length) + s;
}
