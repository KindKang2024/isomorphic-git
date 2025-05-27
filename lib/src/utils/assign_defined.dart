/// Like Object.assign but ignore properties with undefined values
/// ref: https://stackoverflow.com/q/39513815
Map<String, dynamic> assignDefined(Map<String, dynamic> target, List<Map<String, dynamic>?> sources) {
  for (final source in sources) {
    if (source != null) {
      for (final key in source.keys) {
        final val = source[key];
        if (val != null) {
          target[key] = val;
        }
      }
    }
  }
  return target;
}