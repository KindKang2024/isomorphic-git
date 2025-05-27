class NoCommitError extends Error {
  static const String code = 'NoCommitError';
  final String ref;

  NoCommitError(this.ref) : super();

  @override
  String toString() {
    return 'NoCommitError: "$ref" does not point to any commit. You\'re maybe working on a repository with no commits yet. ';
  }
}
