class MissingParameterError extends ArgumentError {
  MissingParameterError(String parameterName) : super('Missing required parameter: $parameterName');
}

void assertParameter(String name, dynamic value) {
  if (value == null) {
    throw MissingParameterError(name);
  }
}