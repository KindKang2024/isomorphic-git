// Assuming the existence of this file/class based on the JS version:
// import '../errors/missing_parameter_error.dart';

// Placeholder for MissingParameterError until its Dart version is defined
class MissingParameterError extends ArgumentError {
  MissingParameterError(String parameterName) : super('Missing required parameter: $parameterName');
}

void assertParameter(String name, dynamic value) {
  if (value == null) {
    throw MissingParameterError(name);
  }
}