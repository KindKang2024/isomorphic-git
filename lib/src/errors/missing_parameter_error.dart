class MissingParameterError extends Error {
  static const String code = 'MissingParameterError';
  final String parameter;

  MissingParameterError(this.parameter) : super();

  @override
  String toString() {
    return 'MissingParameterError: The function requires a "$parameter" parameter but none was provided.';
  }
}
