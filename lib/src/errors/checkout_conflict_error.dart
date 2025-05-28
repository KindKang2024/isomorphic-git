import './base_error.dart';

class CheckoutConflictError extends BaseError {
  final List<String> filepaths;

  CheckoutConflictError(this.filepaths)
      : super( message: 
            'Your local changes to the following files would be overwritten by checkout: ${filepaths.join(', ')}') {
    super.code = "CheckoutConflictError";
    super.data = {'filepaths': filepaths};
  }
}