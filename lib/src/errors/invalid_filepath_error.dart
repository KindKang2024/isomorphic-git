import './base_error.dart';

class InvalidFilepathError extends BaseError {
  final Map<String, dynamic>? data;

  InvalidFilepathError(String message, {this.data}) : super(message:message);

  @override
  String get code => 'InvalidFilepathError';
}