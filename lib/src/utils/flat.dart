List<T> flat<T>(List<List<T>> entries) {
  return entries.expand((x) => x).toList();
}
