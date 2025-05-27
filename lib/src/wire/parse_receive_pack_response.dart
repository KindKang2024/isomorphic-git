import 'dart:async';
import 'dart:convert';

// Assuming GitPktLine.streamReader and read() behavior is to yield Uint8List packet contents
// and then a special marker for end-of-stream (like null or a specific object).
// For now, we'll simulate by reading the whole stream and splitting by lines,
// which is what the JS version effectively does after its read loop.

// Define a class for the structured result
class PushResult {
  bool ok;
  String? error;
  Map<String, RefStatus> refs;

  PushResult({required this.ok, this.error, required this.refs});

  Map<String, dynamic> toJson() => {
    'ok': ok,
    if (error != null) 'error': error,
    'refs': refs.map((key, value) => MapEntry(key, value.toJson())),
  };
}

class RefStatus {
  bool ok;
  String? error;

  RefStatus({required this.ok, this.error});

  Map<String, dynamic> toJson() => {
    'ok': ok,
    if (error != null) 'error': error,
  };
}

class ParseError extends Error {
  final String expected;
  final String actual;
  ParseError(this.expected, this.actual);

  @override
  String toString() {
    return 'ParseError: Expected "$expected" but got "$actual"';
  }
}

Future<PushResult> parseReceivePackResponse(Stream<List<int>> packfile) async {
  // The JS code reads the entire pkt-line stream into a single string first.
  // We will do something similar by collecting lines.
  // This assumes that GitPktLine.streamReader(packfile) and subsequent read() calls
  // would eventually provide lines of text, with special values for true (end) or null (skip).
  // Dart's Stream<List<int>> needs to be decoded and split into lines.

  var responseBuffer = StringBuffer();
  await for (var chunk in packfile.transform(utf8.decoder)) {
    responseBuffer.write(chunk);
  }

  // The original JS code uses a custom GitPktLine.streamReader.
  // It seems to aggregate lines and then split.
  // Let's assume the responseBuffer now contains the full response,
  // and we need to handle pkt-line decoding if it's still in that format.
  // For now, we'll directly work with the accumulated string, assuming it's already decoded from pkt-line.
  // This is a simplification and might need adjustment if the input 'packfile' stream is raw pkt-lines.

  // The JS code splits the response by '\n' after accumulating it.
  // Let's assume 'responseBuffer.toString()' is the equivalent of the fully read 'response' in JS.
  List<String> lines = responseBuffer.toString().split('\n');

  // Filter out potential empty last line if the input ends with \n
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }

  if (lines.isEmpty) {
    throw ParseError('unpack report', 'empty response');
  }

  String firstLine = lines.removeAt(0);
  if (!firstLine.startsWith('unpack ')) {
    throw ParseError('unpack ok" or "unpack [error message]', firstLine);
  }

  bool isOk = firstLine == 'unpack ok';
  String? errorMsg;
  if (!isOk) {
    errorMsg = firstLine.substring('unpack '.length);
  }

  Map<String, RefStatus> refs = {};
  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    // Ensure the line is long enough before slicing
    if (line.length < 3) {
      // Potentially log or handle this malformed line
      print("Skipping malformed line: $line");
      continue;
    }

    final status = line.substring(0, 2);
    final refAndMessage = line.substring(3);

    int space = refAndMessage.indexOf(' ');
    if (space == -1) space = refAndMessage.length;

    final ref = refAndMessage.substring(0, space);
    // Ensure there's something after space if space wasn't end of string
    final error = (space < refAndMessage.length)
        ? refAndMessage.substring(space + 1)
        : null;

    refs[ref] = RefStatus(
      ok: status == 'ok',
      error: error?.isNotEmpty == true ? error : null,
    );
  }

  return PushResult(ok: isOk, error: errorMsg, refs: refs);
}
