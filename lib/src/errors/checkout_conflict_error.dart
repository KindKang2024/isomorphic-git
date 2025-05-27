import './base_error.dart';

class CheckoutConflictError extends BaseError {
  static const String code = 'CheckoutConflictError';

  final List<String> filepaths;

  CheckoutConflictError(this.filepaths)
      : super(
            'Your local changes to the following files would be overwritten by checkout: ${filepaths.join(', ')}') {
    super.code = code;
    super.data = {'filepaths': filepaths};
  }
}