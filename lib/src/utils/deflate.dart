import 'dart:typed_data';
import 'dart:io';

Future<Uint8List> deflate(Uint8List buffer) async {
  final encoder = ZLibEncoder(
    gzip: false,
    level: ZLibOption.defaultLevel,
  );
  final compressed = encoder.convert(buffer);
  return Uint8List.fromList(compressed);
}
