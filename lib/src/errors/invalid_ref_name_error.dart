class InvalidRefNameError extends Error {
  static const String code = 'InvalidRefNameError';
  final String ref;
  final String suggestion;

  InvalidRefNameError(this.ref, this.suggestion) : super();

  @override
  String toString() {
    return 'InvalidRefNameError: "$ref" would be an invalid git reference. (Hint: a valid alternative would be "$suggestion".)';
  }
}
