import 'base_error.dart';

class PushRejectedError extends BaseError {
  final String reason;

  PushRejectedError({required this.reason})
    : super(message: _generateMessage(reason));

  static String _generateMessage(String reason) {
    String message = '';
    if (reason == 'not-fast-forward') {
      message = ' because it was not a simple fast-forward';
    } else if (reason == 'tag-exists') {
      message = ' because tag already exists';
    }
    return 'Push rejected$message. Use "force: true" to override.';
  }

  @override
  String get code => 'PushRejectedError';

  @override
  Map<String, dynamic> get data => {'reason': reason};
}
