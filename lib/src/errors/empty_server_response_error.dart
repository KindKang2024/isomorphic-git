import './base_error.dart';

class EmptyServerResponseError extends BaseError {
  static const String code = 'EmptyServerResponseError';

  EmptyServerResponseError()
      : super('Empty response from git server.') {
    super.code = code;
    super.data = {};
  }
}