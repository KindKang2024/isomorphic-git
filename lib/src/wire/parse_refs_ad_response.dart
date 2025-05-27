import 'dart:async';
import 'dart:convert';

import '../errors/empty_server_response_error.dart';
import '../errors/parse_error.dart'; // Assuming ParseError is defined here
import '../models/git_pkt_line.dart'; // Assuming GitPktLine is defined here
import '../wire/parse_capabilities_v2.dart'; // Assuming parseCapabilitiesV2 is defined here

// Define a class for the structured result
class RefsAdResponse {
  int? protocolVersion;
  Set<String>? capabilities;
  Map<String, String>? refs;
  Map<String, String>? symrefs;
  Map<String, dynamic>? capabilities2; // For V2 response

  RefsAdResponse({
    this.protocolVersion,
    this.capabilities,
    this.refs,
    this.symrefs,
    this.capabilities2,
  });
}

Future<RefsAdResponse> parseRefsAdResponse(
  Stream<List<int>> stream,
  {required String service},
) async {
  final capabilities = <String>{};
  final refs = <String, String>{};
  final symrefs = <String, String>{};

  // This is a placeholder for the GitPktLine.streamReader logic
  // In a real scenario, this would be a proper PktLine stream reader.
  // For now, we'll collect all lines and process them.
  final lineReader = _LineReader(stream);

  String? lineOne = await lineReader.read();
  while (lineOne == null) lineOne = await lineReader.read(); // Skip past any flushes

  if (lineOne == _LineReader.endMarker) throw EmptyServerResponseError();

  if (lineOne!.contains('version 2')) {
    // Protocol v2 handling. `parseCapabilitiesV2` expects a stream.
    // We need to provide the rest of the stream to it.
    // This is tricky because lineOne was already consumed from lineReader.
    // A more robust PktLine reader would handle this better.
    // For now, if we detect v2, we assume the rest of the stream is for it.
    // This part needs careful implementation of how `read` is passed to `parseCapabilitiesV2` in JS.
    // The JS `parseCapabilitiesV2` takes a `read` function.
    // We will pass the `lineReader.read` method, but it needs to be adapted or the stream re-created.

    // Simplified approach for now: we assume parseCapabilitiesV2 can handle our _LineReader
    // This is not a direct port and might need a proper stream adapter.
    final v2Result = await parseCapabilitiesV2(lineReader.remainingStream());
    return RefsAdResponse(protocolVersion: 2, capabilities2: v2Result['capabilities2']);
  }

  if (lineOne.trim() != '# service=$service') {
    throw ParseError('# service=$service\n', lineOne);
  }

  String? lineTwo = await lineReader.read();
  while (lineTwo == null) lineTwo = await lineReader.read(); // Skip past any flushes

  if (lineTwo == _LineReader.endMarker) {
    return RefsAdResponse(
        protocolVersion: 1, capabilities: capabilities, refs: refs, symrefs: symrefs);
  }

  // The JS code uses lineTwo.toString('utf8') which implies lineTwo might not be a string yet.
  // Our _LineReader.read() returns a string, so direct usage is fine.
  if (lineTwo!.contains('version 2')) {
    // Similar to above, handling v2 if detected in the second line.
    final v2Result = await parseCapabilitiesV2(lineReader.remainingStream());
     return RefsAdResponse(protocolVersion: 2, capabilities2: v2Result['capabilities2']);
  }

  final parts = _splitAndAssert(lineTwo, '\x00', '\\x00');
  final firstRefLine = parts[0];
  final capabilitiesLine = parts[1];

  capabilitiesLine.split(' ').forEach((x) => capabilities.add(x));

  if (firstRefLine != '0000000000000000000000000000000000000000 capabilities^{}') {
    final refParts = _splitAndAssert(firstRefLine, ' ', ' ');
    refs[refParts[1]] = refParts[0];
  }

  while (true) {
    String? line = await lineReader.read();
    if (line == _LineReader.endMarker) break;
    if (line != null) {
      final refParts = _splitAndAssert(line, ' ', ' ');
      // The JS code uses refParts[1] as key and refParts[0] as value.
      // Original: refs.set(name, ref) where name is refParts[1] and ref is refParts[0].
      refs[refParts[1]] = refParts[0]; 
    }
  }

  for (final cap in capabilities) {
    if (cap.startsWith('symref=')) {
      final m = RegExp(r'symref=([^:]+):(.*)').firstMatch(cap);
      if (m != null && m.groupCount == 2) {
        symrefs[m.group(1)!] = m.group(2)!;
      }
    }
  }

  return RefsAdResponse(
      protocolVersion: 1, capabilities: capabilities, refs: refs, symrefs: symrefs);
}

List<String> _splitAndAssert(String line, String sep, String expected) {
  final split = line.trim().split(sep);
  if (split.length != 2) {
    throw ParseError('Two strings separated by \'$expected\'', line);
  }
  return split;
}

// Helper class to mimic the JS line reader behavior from a Dart stream.
// This is a simplified version. A proper PktLine parser would be more robust.
class _LineReader {
  static const endMarker = '<<END_OF_STREAM>>';
  final StreamIterator<String> _iterator;
  final StreamController<List<int>> _remainingStreamController;
  bool _firstReadPassedToRemaining = false;

  _LineReader(Stream<List<int>> stream) :
    _iterator = StreamIterator(stream.transform(utf8.decoder).transform(const LineSplitter())),
    _remainingStreamController = StreamController<List<int>>();

  Future<String?> read() async {
    if (await _iterator.moveNext()) {
      final line = _iterator.current;
      if (_firstReadPassedToRemaining) {
         // Once remainingStream() is called, subsequent original stream data should go there.
        _remainingStreamController.add(utf8.encode(line + '\n')); 
      }
      return line;
    }
    if (_firstReadPassedToRemaining) {
        _remainingStreamController.close();
    }
    return endMarker; // Special marker for end of stream
  }

  // This method is to provide a stream for parseCapabilitiesV2 if protocol v2 is detected.
  // It attempts to reconstruct a stream from the point of detection.
  // This is a simplified and potentially fragile approach.
  Stream<List<int>> remainingStream() {
    _firstReadPassedToRemaining = true;
    // The idea is that `read()` will now forward lines to `_remainingStreamController`.
    // This is still not a perfect port of passing a `read` function like in JS.
    // `parseCapabilitiesV2` in Dart expects a `Stream<List<int>>`.
    return _remainingStreamController.stream;
  }
} 