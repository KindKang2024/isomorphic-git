import 'base_error.dart';

class RemoteCapabilityError extends BaseError {
  final String capability;
  final String parameter;

  RemoteCapabilityError({required this.capability, required this.parameter})
    : super(
        message:
            'Remote does not support the "$capability" so the "$parameter" parameter cannot be used.',
      );

  @override
  String get code => 'RemoteCapabilityError';

  @override
  Map<String, dynamic> get data => {
    'capability': capability,
    'parameter': parameter,
  };
}
