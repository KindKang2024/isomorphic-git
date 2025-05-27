import './base_error.dart';

class HttpError extends BaseError {
  final Map<String, dynamic>? data;

  HttpError(super.message, {this.data});

  @override
  String get code => 'HttpError';
}