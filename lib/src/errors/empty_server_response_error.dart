import './base_error.dart';

class EmptyServerResponseError extends BaseError {
  EmptyServerResponseError()
      : super(message:'Empty response from git server.') {
    super.code = "EmptyServerResponseError";
    super.data = {};
  }
}