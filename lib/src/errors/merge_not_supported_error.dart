class MergeNotSupportedError extends Error {
  static const String code = 'MergeNotSupportedError';

  MergeNotSupportedError() : super();

  @override
  String toString() {
    return 'MergeNotSupportedError: Merges with conflicts are not supported yet.';
  }
}
