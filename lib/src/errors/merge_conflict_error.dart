class MergeConflictError extends Error {
  static const String code = 'MergeConflictError';
  final List<String> filepaths;
  final List<String> bothModified;
  final List<String> deleteByUs;
  final List<String> deleteByTheirs;

  MergeConflictError(
    this.filepaths,
    this.bothModified,
    this.deleteByUs,
    this.deleteByTheirs,
  ) : super();

  @override
  String toString() {
    return 'MergeConflictError: Automatic merge failed with one or more merge conflicts in the following files: ${filepaths.join(", ")}. Fix conflicts then commit the result.';
  }
}
