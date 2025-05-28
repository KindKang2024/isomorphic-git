import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Utility functions for Git operations
class GitUtils {
  /// Calculate SHA-1 hash of data
  static String sha1Hash(Uint8List data) {
    final digest = sha1.convert(data);
    return digest.toString();
  }

  /// Convert string to UTF-8 bytes
  static Uint8List stringToBytes(String str) {
    return Uint8List.fromList(utf8.encode(str));
  }

  /// Convert bytes to UTF-8 string
  static String bytesToString(Uint8List bytes) {
    return utf8.decode(bytes);
  }

  /// Validate Git object ID (SHA-1 hash)
  static bool isValidOid(String oid) {
    if (oid.length != 40) return false;
    return RegExp(r'^[a-f0-9]{40}$').hasMatch(oid);
  }

  /// Validate Git reference name
  static bool isValidRefName(String refName) {
    // Basic validation - can be expanded
    if (refName.isEmpty) return false;
    if (refName.startsWith('.') || refName.endsWith('.')) return false;
    if (refName.contains('..')) return false;
    if (refName.contains(' ')) return false;
    return true;
  }
}
