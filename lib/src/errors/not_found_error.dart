class NotFoundError extends Error {
  static const String code = 'NotFoundError';
  final String what;

  NotFoundError(this.what) : super();

  @override
  String toString() {
    return 'NotFoundError: Could not find $what.';
  }
}
