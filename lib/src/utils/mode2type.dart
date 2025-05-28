class InternalError implements Exception {
  final String message;
  InternalError(this.message);
  @override
  String toString() => 'InternalError: $message';
}

String mode2type(int mode) {
  switch (mode) {
    case 0x4000: // 040000 in octal - tree (directory)
      return 'tree';
    case 0x81A4: // 100644 in octal - blob (regular file)
    case 0x81ED: // 100755 in octal - blob (executable file)
    case 0xA000: // 120000 in octal - blob (symbolic link)
      return 'blob';
    case 0xE000: // 160000 in octal - commit (gitlink/submodule)
      return 'commit';
    default:
      throw InternalError(
        'Unexpected GitTree entry mode: ${mode.toRadixString(8)}',
      );
  }
}
