import 'dart:typed_data';
import 'dart:io'; // For ZLibEncoder
import 'package:archive/archive.dart'; // Ensure 'archive' is in your pubspec.yaml

// Note: pako.deflate is equivalent to zlib.deflate in Node.js,
// which uses the DEFLATE algorithm.
// Dart's ZLibEncoder with gzip: false should provide similar functionality.

Future<Uint8List> deflate(Uint8List buffer) async {
  // In Dart, ZLibEncoder can be used for DEFLATE.
  // The 'gzip: false' option makes it use the ZLIB format (which includes a header and checksum),
  // or raw DEFLATE if level is set appropriately and no header/footer is desired.
  // For typical Git object deflation, raw DEFLATE is used.
  // Pako's default deflate is zlib-wrapped. For raw deflate, specific options are needed.
  // Let's assume standard zlib-wrapped DEFLATE for now, similar to pako's default.

  final encoder = ZLibEncoder(gzip: false, level: ZLibOption.defaultLevel);
  final compressed = encoder.convert(buffer);
  return Uint8List.fromList(compressed);
}

// If you specifically need raw DEFLATE (without zlib wrapper), it's more complex
// and might require a package or manual implementation if not directly supported
// by ZLibEncoder in the desired raw format.
// For Git, raw DEFLATE is often what's needed for zlib-compressed objects.
// The `pako` library in JavaScript can produce raw deflate streams.
// The `archive` package in Dart is a good option for more control over compression formats.
// For example, using the 'archive' package for raw deflate:
/*
import 'package:archive/archive.dart'; // Add 'archive' to your pubspec.yaml

// This function will perform raw DEFLATE compression, which is typically
// what's needed for Git objects (without zlib headers/footers).
Future<Uint8List> deflate(Uint8List buffer) async {
  // The `Deflate` class from the 'archive' package performs raw DEFLATE.
  final deflater = Deflate(buffer, level: Deflate.DEFAULT_COMPRESSION);
  return Uint8List.fromList(deflater.getBytes());
}

// If you needed zlib-wrapped DEFLATE (like pako's default or Node.js zlib.deflate),
// you could use ZLibEncoder from dart:io as previously shown, or the
// ZLibEncoder class from the 'archive' package for more options.
// Future<Uint8List> deflateWithZlibWrapper(Uint8List buffer) async {
//   final encoder = ZLibEncoder(); // from package:archive/archive.dart
//   final compressed = encoder.encode(buffer);
//   return Uint8List.fromList(compressed);
// }
*/