bool emptyPackfile(List<int> pack) {
  const pheader = '5041434b';
  const version = '00000002';
  const obCount = '00000000';
  const header = pheader + version + obCount;
  final slice = pack.take(12).toList();
  final hex = slice.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return hex == header;
}
