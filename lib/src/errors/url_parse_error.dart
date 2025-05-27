import 'base_error.dart';

class UrlParseError extends BaseError {
  final String url;

  UrlParseError({required this.url})
    : super(message: 'Cannot parse remote URL: "$url"');

  @override
  String get code => 'UrlParseError';

  @override
  Map<String, dynamic> get data => {'url': url};
}
