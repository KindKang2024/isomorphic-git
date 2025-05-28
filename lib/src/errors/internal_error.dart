import './base_error.dart';

class InternalError extends BaseError {

  InternalError(String message) : super(message:message);

  @override
  String get code => 'InternalError';

  // No specific data properties for this error in the JS version
}