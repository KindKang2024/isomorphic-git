class InternalError implements Exception {
  final String message;
  InternalError(this.message);
  @override
  String toString() => 'InternalError: $message';
}

String mode2type(int mode) {
  if (mode == 0o040000) {
    return 'tree';
  } else if (mode == 0o100644 || mode == 0o100755 || mode == 0o120000) {
    return 'blob';
  } else if (mode == 0o160000) {
    return 'commit';
  } else {
    throw InternalError('Unexpected GitTree entry mode: ${mode.toRadixString(8)}');
  }
} 