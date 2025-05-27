class InvalidOidError extends Error {
  static const String code = 'InvalidOidError';
  final String value;

  InvalidOidError(this.value) : super();

  @override
  String toString() {
    return 'InvalidOidError: Expected a 40-char hex object id but saw "$value".';
  }
}
