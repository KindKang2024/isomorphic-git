class MissingNameError extends Error {
  static const String code = 'MissingNameError';
  final String role;

  MissingNameError(this.role) : super();

  @override
  String toString() {
    return 'MissingNameError: No name was provided for $role in the argument or in the .git/config file.';
  }
}
