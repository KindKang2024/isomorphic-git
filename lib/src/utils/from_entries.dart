Map<String, String> fromEntries(Map map) {
  final o = <String, String>{};
  map.forEach((key, value) {
    o[key.toString()] = value.toString();
  });
  return o;
}
