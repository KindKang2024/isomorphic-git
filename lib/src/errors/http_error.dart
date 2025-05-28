import './base_error.dart';

class HttpError extends BaseError {
  final Map<String, dynamic>? data;

  HttpError(String message, {this.data}) : super(message:message);

  @override
  String get code => 'HttpError';
}