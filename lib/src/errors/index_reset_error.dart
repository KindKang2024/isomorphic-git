class IndexResetError extends Error {
  static const String code = 'IndexResetError';
  final String filepath;

  IndexResetError(this.filepath) : super();

  @override
  String toString() {
    return 'IndexResetError: Could not merge index: Entry for \'$filepath\' is not up to date. Either reset the index entry to HEAD, or stage your unstaged changes.';
  }
}
