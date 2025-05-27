import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

// Helper function to convert a list of bytes to a hex string.
// This replaces the toHex.js utility.
String _toHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
}

/// Computes the SHA-1 hash of the given [buffer].
///
/// This function provides similar functionality to the original shasum.js,
/// but uses Dart's `crypto` package for SHA-1 calculation.
Future<String> shasum(Uint8List buffer) async {
  // In Dart, crypto.sha1.convert() is synchronous but we keep the async signature
  // to match the original JS function and allow for potential future async operations if needed.
  final digest = crypto.sha1.convert(buffer.toList());
  return _toHex(digest.bytes);
}

/// Synchronous version of shasum.
String shasumSync(Uint8List buffer) {
  final digest = crypto.sha1.convert(buffer.toList());
  return _toHex(digest.bytes);
}

// Note: The original JavaScript code had a mechanism to test and use
// `crypto.subtle.digest` if available in the browser. This is not directly
// applicable in Dart, as the `crypto` package provides a standard way
// to perform SHA-1 hashing. The `testSubtleSHA1` and related logic
// have been omitted as they are specific to browser environments.