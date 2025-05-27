import 'base_error.dart';

class UnknownTransportError extends BaseError {
  final String url;
  final String transport;
  final String? suggestion;

  UnknownTransportError({
    required this.url,
    required this.transport,
    this.suggestion,
  }) : super(
         message:
             'Git remote "$url" uses an unrecognized transport protocol: "$transport"',
       );

  @override
  String get code => 'UnknownTransportError';

  @override
  Map<String, dynamic> get data => {
    'url': url,
    'transport': transport,
    'suggestion': suggestion,
  };
}
