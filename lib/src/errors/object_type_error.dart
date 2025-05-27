import 'base_error.dart';

class ObjectTypeError extends BaseError {
  final String oid;
  final String actual;
  final String expected;
  final String? filepath;

  ObjectTypeError({
    required this.oid,
    required this.actual,
    required this.expected,
    this.filepath,
  }) : super(
         message:
             'Object $oid ${filepath != null ? 'at $filepath' : ''}was anticipated to be a $expected but it is a $actual.',
       );

  @override
  String get code => 'ObjectTypeError';

  @override
  Map<String, dynamic> get data => {
    'oid': oid,
    'actual': actual,
    'expected': expected,
    'filepath': filepath,
  };
}
