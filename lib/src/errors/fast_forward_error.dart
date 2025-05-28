import './base_error.dart';

class FastForwardError extends BaseError {
  FastForwardError(String message) : super(message: message );

  @override
  String get code => 'FastForwardError';

  // No specific data properties for this error in the JS version
}