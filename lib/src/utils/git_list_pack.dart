import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
// import 'package:pako/pako.dart'; // No direct Dart equivalent; use zlib
// import '../errors/internal_error.dart'; // TODO: Implement or import InternalError
// import 'stream_reader.dart'; // TODO: Implement or import StreamReader

import '../utils/stream_reader.dart';
import 'package:archive/archive.dart';
import '../errors/internal_error.dart';

// TODO: Implement InternalError equivalent in Dart
class InternalError implements Exception {
  final String message;
  InternalError(this.message);
  @override
  String toString() => 'InternalError: $message';
}

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
  var packStr = utf8.decode(pack);
  if (packStr != 'PACK') {
    throw InternalError('Invalid PACK header \'$packStr\'');
  }

  var versionBytes = await reader.read(4);
  var version = ByteData.view(versionBytes.buffer).getUint32(0, Endian.big);
  if (version != 2) {
    throw InternalError('Invalid packfile version: $version');
  }

  var numObjectsBytes = await reader.read(4);
  var numObjects = ByteData.view(
    numObjectsBytes.buffer,
  ).getUint32(0, Endian.big);
  if (numObjects < 1) return;

  while (!reader.eof() && numObjects-- > 0) {
    final offset = reader.tell();
    final header = await _parseHeader(reader);
    final type = header.type;
    final length = header.length;
    final ofs = header.ofs;
    final reference = header.reference;

    // Pako.inflate is equivalent to Inflate(windowBits: 15).inflate in Dart
    final inflator = Inflate(windowBits: 15);
    Uint8List? resultData;

    // This loop mimics the pako behavior of reading chunks until the inflator has a result.
    // In Dart, `Inflate.inflate` processes the entire input at once.
    // We need to simulate chunked processing to match the original logic for backtracking.
    List<int> accumulatedBytes = [];
    int lastChunkSize = 0;

    while (resultData == null) {
      final chunk = await reader.chunk();
      if (chunk == null) break;
      accumulatedBytes.addAll(chunk);
      lastChunkSize = chunk.length;

      try {
        resultData = Uint8List.fromList(
          inflator.inflate(Uint8List.fromList(accumulatedBytes)),
        );
      } catch (e) {
        // Continue accumulating if inflate fails, assuming more data is needed
        // or it might be an error that will be caught later by length check.
        if (reader.eof()) {
          // If EOF and still error, then throw
          throw InternalError('Inflate error: $e');
        }
      }

      if (resultData != null) {
        if (resultData.length != length) {
          throw InternalError(
            'Inflated object size is different from that stated in packfile. Expected $length, got ${resultData.length}',
          );
        }

        // Calculate how many bytes of the last chunk were actually consumed by the inflator.
        // This is a bit tricky because Dart's Inflate doesn't directly expose `avail_in` like Pako.
        // We estimate consumed bytes. The original JS code backtracks by chunk.length - inflator.strm.avail_in.
        // Since Dart's inflate consumes what it needs or throws an error if data is incomplete,
        // we assume the inflator consumed all bytes up to the point it could successfully inflate to `length`.
        // The crucial part is that `reader.read` should position the stream correctly for the next object.

        // The original JS code does:
        // await reader.undo() // (effectively moves back by the last chunk read)
        // await reader.read(chunk.length - inflator.strm.avail_in) // (reads the consumed part of the chunk)

        // Find the end of the deflated data. This is complex because `Inflate` doesn't tell us how much it consumed from the input buffer.
        // For now, we'll assume the `StreamReader` handles its internal offset correctly when `read` is called subsequently.
        // The critical part is that `reader.tell()` before reading the next header gives the correct offset.
        // The original code relies on knowing how much of the *last read chunk* was *not* consumed by pako.
        // We will try to find the smallest amount of `accumulatedBytes` that produces `resultData`

        int consumedLength = 0;
        for (int i = 1; i <= accumulatedBytes.length; i++) {
          try {
            final testData = Uint8List.fromList(
              inflator.inflate(
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
          // If we couldn't find the exact consumed length but got a result,
          // it means the whole accumulatedBytes was likely needed.
          // This can happen if the compressed data itself is very small.
          if (resultData.length == length) {
            consumedLength = accumulatedBytes.length;
          } else {
            throw InternalError(
              'Could not determine consumed length for inflated data.',
            );
          }
        }

        await reader
            .undo(); // Go back by lastChunkSize (which was `chunk.length`)
        await reader.read(
          consumedLength - (accumulatedBytes.length - lastChunkSize),
        ); // Read only the consumed part

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
  final type = (byte >> 4) & 0x07;
  var length = byte & 0x0F;

  if ((byte & 0x80) != 0) {
    var shift = 4;
    do {
      byte = await reader.byte();
      length |= (byte & 0x7F) << shift;
      shift += 7;
    } while ((byte & 0x80) != 0);
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
      // The original code for ofs was: ofs |= (byte & 0b01111111) << shift;
      // However, ofs_delta is a negative offset from the current object's start.
      // The MSB of the first byte is 0. For subsequent bytes, MSB is 1 except for the last byte.
      // Each byte contributes 7 bits to the offset.
      // The value is stored as base-128 variant of a variable length integer.
      // The original JS seems to just read it as a positive number then uses it in packfile parser.
      // For now, mirroring the JS logic to build `reference` which seems to be the raw bytes of the offset.
      if (bytes.isEmpty) {
        // first byte
        ofs = byte & 0x7F;
      } else {
        ofs = (ofs + 1) << 7 | (byte & 0x7F); // this is from libgit2
      }
      bytes.add(byte);
      shift +=
          7; // not directly used for `ofs` like this in git spec, but `reference` takes raw bytes
    } while ((byte & 0x80) != 0);
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
