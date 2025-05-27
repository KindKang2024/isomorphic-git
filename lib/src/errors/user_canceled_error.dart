import 'base_error.dart';

class UserCanceledError extends BaseError {
  UserCanceledError() : super(message: 'The operation was canceled.');

  @override
  String get code => 'UserCanceledError';

  @override
  Map<String, dynamic> get data => {};
}
