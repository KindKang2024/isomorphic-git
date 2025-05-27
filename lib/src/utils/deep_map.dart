Map<dynamic, dynamic> _deepGet(List<dynamic> keys, Map<dynamic, dynamic> map) {
  Map<dynamic, dynamic> currentMap = map;
  for (final key in keys) {
    if (!currentMap.containsKey(key)) {
      currentMap[key] = <dynamic, dynamic>{};
    }
    var nextMap = currentMap[key];
    if (nextMap is! Map<dynamic, dynamic>) {
      // This case handles if a non-map was previously inserted at this key path.
      // Depending on desired behavior, you might throw an error or overwrite.
      // For this translation, we'll overwrite to align with the JS behavior
      // where map.set(key, new Map()) would replace a non-map value.
      currentMap[key] = <dynamic, dynamic>{};
      nextMap = currentMap[key];
    }
    currentMap = nextMap;
  }
  return currentMap;
}

class DeepMap {
  final Map<dynamic, dynamic> _root = <dynamic, dynamic>{};

  void set(List<dynamic> keys, dynamic value) {
    if (keys.isEmpty) {
      throw ArgumentError('Keys list cannot be empty for set operation.');
    }
    final List<dynamic> basePathKeys = List.from(keys);
    final dynamic lastKey = basePathKeys.removeLast();
    final Map<dynamic, dynamic> lastMap = _deepGet(basePathKeys, _root);
    lastMap[lastKey] = value;
  }

  dynamic get(List<dynamic> keys) {
    if (keys.isEmpty) {
      // Or return null, or handle as per specific requirements
      throw ArgumentError('Keys list cannot be empty for get operation.');
    }
    final List<dynamic> basePathKeys = List.from(keys);
    final dynamic lastKey = basePathKeys.removeLast();
    final Map<dynamic, dynamic> lastMap = _deepGet(basePathKeys, _root);
    return lastMap[lastKey];
  }

  bool has(List<dynamic> keys) {
    if (keys.isEmpty) {
      return false; // Or throw error, depending on desired behavior for empty keys
    }
    final List<dynamic> basePathKeys = List.from(keys);
    final dynamic lastKey = basePathKeys.removeLast();
    final Map<dynamic, dynamic> lastMap = _deepGet(basePathKeys, _root);
    return lastMap.containsKey(lastKey);
  }
}