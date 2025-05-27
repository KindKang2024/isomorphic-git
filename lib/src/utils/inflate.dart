import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

Future<Uint8List> inflate(Uint8List buffer) async {
  // In Dart, use zlib.decode for deflate
  // For browser support, additional work may be needed
  return Uint8List.fromList(zlib.decode(buffer));
}
