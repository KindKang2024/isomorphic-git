import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'stream_reader.dart';
import 'package:archive/archive.dart';
import '../errors/internal_error.dart';

class ListPackResult {
  final Uint8List data;
  final int type;
  final int num;
  final int offset;
  final int end;
  final dynamic reference;
  final int? ofs;

  ListPackResult({
    required this.data,
    required this.type,
    required this.num,
    required this.offset,
    required this.end,
    this.reference,
    this.ofs,
  });
}

typedef OnDataCallback = Future<void> Function(ListPackResult result);

Future<void> listpack(Stream<Uint8List> stream, OnDataCallback onData) async {
  final reader = StreamReader(stream);
  var pack = await reader.read(4);
  var packStr = utf8.decode(pack!);
  if (packStr != 'PACK') {
    throw InternalError('Invalid PACK header \'$packStr\'');
  }

  var versionBytes = await reader.read(4);
  var version = ByteData.view(versionBytes!.buffer).getUint32(0, Endian.big);
  if (version != 2) {
    throw InternalError('Invalid packfile version: $version');
  }

  var numObjectsBytes = await reader.read(4);
  var numObjects = ByteData.view(
    numObjectsBytes!.buffer,
  ).getUint32(0, Endian.big);
  if (numObjects < 1) return;

  while (!reader.eof() && numObjects-- > 0) {
    final offset = reader.tell();
    final header = await _parseHeader(reader);
    final type = header.type;
    final length = header.length;
    final ofs = header.ofs;
    final reference = header.reference;

    // Use ZLibDecoder from the archive package for inflation
    Uint8List? resultData;

    List<int> accumulatedBytes = [];
    int lastChunkSize = 0;

    while (resultData == null) {
      final chunk = await reader.chunk();
      if (chunk == null) break;
      accumulatedBytes.addAll(chunk);
      lastChunkSize = chunk.length;

      try {
        // Use ZLibDecoder for inflation (note the capital L)
        final decoder = ZLibDecoder();
        resultData = Uint8List.fromList(
          decoder.decodeBytes(
            Uint8List.fromList(accumulatedBytes),
          ),
        );
      } catch (e) {
        // Continue accumulating if inflate fails, assuming more data is needed
        if (reader.eof()) {
          throw InternalError('Inflate error: $e');
        }
      }

      if (resultData != null) {
        if (resultData.length != length) {
          throw InternalError(
            'Inflated object size is different from that stated in packfile. Expected $length, got ${resultData.length}',
          );
        }

        int consumedLength = 0;
        for (int i = 1; i <= accumulatedBytes.length; i++) {
          try {
            // Use ZLibDecoder for inflation trial
            final decoder = ZLibDecoder();
            final testData = Uint8List.fromList(
              decoder.decodeBytes(
                Uint8List.fromList(accumulatedBytes.sublist(0, i)),
              ),
            );
            if (testData.length == length) {
              consumedLength = i;
              break;
            }
          } catch (e) {
            // ignore
          }
        }
        if (consumedLength == 0 && accumulatedBytes.isNotEmpty) {
          if (resultData.length == length) {
            consumedLength = accumulatedBytes.length;
          } else {
            throw InternalError(
              'Could not determine consumed length for inflated data.',
            );
          }
        }

        reader.undo();
        await reader.read(
          consumedLength - (accumulatedBytes.length - lastChunkSize),
        );

        final end = reader.tell();
        await onData(
          ListPackResult(
            data: resultData,
            type: type,
            num: numObjects,
            offset: offset,
            end: end,
            reference: reference,
            ofs: ofs,
          ),
        );
      }
    }
  }
}

class _HeaderResult {
  final int type;
  final int length;
  final int? ofs;
  final dynamic reference;

  _HeaderResult({
    required this.type,
    required this.length,
    this.ofs,
    this.reference,
  });
}

Future<_HeaderResult> _parseHeader(StreamReader reader) async {
  var byte = await reader.byte();
  final type = (byte! >> 4) & 0x07;
  var length = byte & 0x0F;

  if ((byte & 0x80) != 0) {
    var shift = 4;
    do {
      byte = await reader.byte();
      length |= (byte! & 0x7F) << shift;
      shift += 7;
    } while ((byte! & 0x80) != 0);
  }

  int? ofs;
  dynamic reference;

  if (type == 6) {
    // OFS_DELTA
    var shift = 0;
    ofs = 0;
    final bytes = <int>[];
    do {
      byte = await reader.byte();
      if (bytes.isEmpty) {
        ofs = byte! & 0x7F;
      } else {
        ofs = (ofs! + 1) << 7 | (byte! & 0x7F);
      }
      bytes.add(byte!);
      shift += 7;
    } while ((byte! & 0x80) != 0);
    reference = Uint8List.fromList(bytes);
  }

  if (type == 7) {
    // REF_DELTA
    final buf = await reader.read(20);
    reference = buf;
  }

  return _HeaderResult(
    type: type,
    length: length,
    ofs: ofs,
    reference: reference,
  );
}
