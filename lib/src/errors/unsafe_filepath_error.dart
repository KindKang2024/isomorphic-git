import 'base_error.dart';

class UnsafeFilepathError extends BaseError {
  final String filepath;

  UnsafeFilepathError({required this.filepath})
    : super(
        message: 'The filepath "$filepath" contains unsafe character sequences',
      );

  @override
  String get code => 'UnsafeFilepathError';

  @override
  Map<String, dynamic> get data => {'filepath': filepath};
}
