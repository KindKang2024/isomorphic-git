import 'base_error.dart';

class SmartHttpError extends BaseError {
  final String preview;
  final String response;

  SmartHttpError({required this.preview, required this.response})
    : super(
        message:
            'Remote did not reply using the "smart" HTTP protocol. Expected "001e# service=git-upload-pack" but received: $preview',
      );

  @override
  String get code => 'SmartHttpError';

  @override
  Map<String, dynamic> get data => {'preview': preview, 'response': response};
}
