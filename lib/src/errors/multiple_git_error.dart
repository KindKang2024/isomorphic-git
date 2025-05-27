class MultipleGitError extends Error {
  static const String code = 'MultipleGitError';
  final List<Error> errors;

  MultipleGitError(this.errors) : super();

  @override
  String toString() {
    return 'MultipleGitError: There are multiple errors that were thrown by the method. Please refer to the "errors" property to see more';
  }
}
