import 'base_error.dart';

class ParseError extends BaseError {
  final String expected;
  final String actual;

  ParseError({required this.expected, required this.actual})
    : super(message: 'Expected "$expected" but received "$actual".');

  @override
  String get code => 'ParseError';

  @override
  Map<String, dynamic> get data => {'expected': expected, 'actual': actual};
}
