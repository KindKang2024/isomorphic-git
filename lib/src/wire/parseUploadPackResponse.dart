import 'dart:async';
import 'dart:convert';

import '../errors/invalid_oid_error.dart';
import '../models/git_side_band.dart';

Future<Map<String, dynamic>> parseUploadPackResponse(
  Stream<List<int>> stream,
) async {
  final demuxed = GitSideBand.demux(stream);
  final packetlines = demuxed.packetlines;
  final packfile = demuxed.packfile;
  final progress = demuxed.progress;

  final shallows = <String>[];
  final unshallows = <String>[];
  final acks = <Map<String, String?>>[];
  bool nak = false;
  bool done = false;

  final completer = Completer<Map<String, dynamic>>();

  StreamSubscription? sub;
  sub = packetlines.listen(
    (data) {
      final line = utf8.decode(data).trim();
      if (line.startsWith('shallow')) {
        final oid = line.substring(line.length - 41).trim();
        if (oid.length != 40) {
          completer.completeError(InvalidOidError(oid));
          sub?.cancel();
          return;
        }
        shallows.add(oid);
      } else if (line.startsWith('unshallow')) {
        final oid = line.substring(line.length - 41).trim();
        if (oid.length != 40) {
          completer.completeError(InvalidOidError(oid));
          sub?.cancel();
          return;
        }
        unshallows.add(oid);
      } else if (line.startsWith('ACK')) {
        final parts = line.split(' ');
        final oid = parts[1];
        final status = parts.length > 2 ? parts[2] : null;
        acks.add({'oid': oid, 'status': status});
        if (status == null) done = true;
      } else if (line.startsWith('NAK')) {
        nak = true;
        done = true;
      } else {
        done = true;
        nak = true;
      }

      if (done) {
        // TODO: how to access stream.error?
        // stream.error != null
        //     ? completer.completeError(stream.error!)
        completer.complete({
          'shallows': shallows,
          'unshallows': unshallows,
          'acks': acks,
          'nak': nak,
          'packfile': packfile,
          'progress': progress,
        });
        sub?.cancel();
      }
    },
    onError: (e) {
      completer.completeError(e);
      sub?.cancel();
    },
    onDone: () {
      if (!completer.isCompleted) {
        // TODO: how to access stream.error?
        // stream.error != null
        //     ? completer.completeError(stream.error!)
        completer.complete({
          'shallows': shallows,
          'unshallows': unshallows,
          'acks': acks,
          'nak': nak,
          'packfile': packfile,
          'progress': progress,
        });
      }
    },
  );
  return completer.future;
}
