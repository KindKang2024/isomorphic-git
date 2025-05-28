import './base_error.dart';

class GitPushError extends BaseError {
  final Map<String, dynamic>? data;

  GitPushError(String message, {this.data}) : super(message:message);

  @override
  String get code => 'GitPushError';
}