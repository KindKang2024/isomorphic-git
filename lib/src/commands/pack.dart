import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:crypto/crypto.dart';
import '../commands/types.dart';
import '../storage/read_object.dart';
import '../utils/deflate.dart';
import '../utils/pad_hex.dart';
import 'package:path/path.dart' as p;

Future<List<Uint8List>> pack({
  required Directory fs,
  required dynamic cache,
  String? dir,
  String? gitdir,
  required List<String> oids,
}) async {
  final gitDirectory = dir != null ? p.join(dir, '.git') : gitdir!;
  final hash = sha1.newInstance();
  final outputStream = <Uint8List>[];

  void write(ByteData chunk, [String? enc]) {
    // In Dart, ByteData is already a view on a Uint8List. We can get the underlying bytes.
    final buff = chunk.buffer.asUint8List(
      chunk.offsetInBytes,
      chunk.lengthInBytes,
    );
    outputStream.add(buff);
    hash.update(buff);
  }

  // Helper to convert string to ByteData (assuming UTF-8 for strings like 'PACK')
  ByteData stringToByteData(String str) {
    return Uint8List.fromList(str.codeUnits).buffer.asByteData();
  }

  // Helper to convert hex string to ByteData
  ByteData hexToByteData(String hexStr) {
    final len = hexStr.length;
    final bytes = Uint8List(len ~/ 2);
    for (var i = 0; i < len; i += 2) {
      bytes[i ~/ 2] = int.parse(hexStr.substring(i, i + 2), radix: 16);
    }
    return bytes.buffer.asByteData();
  }

  Future<void> writeObject(String type, Uint8List object) async {
    final typeNum = GitObjectType.values
        .firstWhere((e) => e.toString().split('.').last == type)
        .index;
    var length = object.lengthInBytes;

    var multibyte = length > 0x0F ? 0x80 : 0x00;
    final lastFour = length & 0x0F;
    length = length >> 4;

    var byte = multibyte | (typeNum << 4) | lastFour;
    var writer = ByteDataWriter();
    writer.writeUint8(byte);
    write(writer.toBytes().buffer.asByteData());

    writer = ByteDataWriter(); // Reset writer for the next part
    while (multibyte != 0) {
      multibyte = length > 0x7F ? 0x80 : 0x00;
      byte = multibyte | (length & 0x7F);
      writer.writeUint8(byte);
      length = length >> 7;
    }
    if (writer.length > 0) {
      write(writer.toBytes().buffer.asByteData());
    }

    final compressedObject = await deflate(object);
    write(
      compressedObject.buffer.asByteData(
        compressedObject.offsetInBytes,
        compressedObject.lengthInBytes,
      ),
    );
  }

  write(stringToByteData('PACK'));
  write(hexToByteData('00000002'));

  var headerWriter = ByteDataWriter();
  headerWriter.writeUint32(oids.length);
  write(headerWriter.toBytes().buffer.asByteData());

  for (final oid in oids) {
    final objectRead = await readObject(
      fs: fs,
      cache: cache,
      gitdir: gitDirectory,
      oid: oid,
    );
    await writeObject(objectRead.type, objectRead.object as Uint8List);
  }

  final digest = hash.convert(
    outputStream.expand((x) => x).toList(),
  ); // hash.digest();
  outputStream.add(Uint8List.fromList(digest.bytes));
  return outputStream;
}
