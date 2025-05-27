import 'dart:async';
import 'dart:convert';

import '../models/git_pkt_line.dart';

// TODO: Define ServerRef if it's a class/interface, or use Map<String, String>
// typedef ServerRef = Map<String, String>;

Future<List<Map<String, String>>> parseListRefsResponse(
  Stream<List<int>> stream,
) async {
  final read = GitPktLine.streamReader(stream);
  final refs = <Map<String, String>>[];

  await for (var lineBytes in stream) {
    // Assuming read() in JS corresponds to processing each chunk of bytes
    // This part needs to be adapted based on how GitPktLine.streamReader and read() actually work
    // For now, assuming 'lineBytes' is what 'read()' would produce (a full line or PktLine object)

    if (lineBytes == true)
      break; // This condition likely needs to change based on actual stream end detection
    if (lineBytes == null) continue; // And this one for empty/null lines

    final line = utf8.decode(lineBytes).trim();
    if (line.isEmpty) continue;

    // This is a placeholder for the actual PktLine parsing logic
    // It needs to correctly interpret the line based on the PktLine format
    // For now, let's assume the line is already the data part of a PktLine
    if (line.startsWith('ERR ')) {
      throw Exception(line.substring(4));
    }
    if (line == '# service=git-upload-pack' || line == '0000') continue;

    // Hacky way to skip the first line and flush packets
    if (line.length < 44 ||
        line.startsWith("shallow") ||
        line.startsWith("unshallow") ||
        line.startsWith("deepen") ||
        line.startsWith("ACK") ||
        line.startsWith("NAK")) {
      // This is not a ref line, so skip
      continue;
    }

    // Example of direct parsing if the line is already a ref line string
    // Format: "oid refname\0capability capability..." or "oid refname"
    // We need to handle the null character and capabilities if present.
    String refLine = line;
    final nullCharIndex = line.indexOf('\x00');
    if (nullCharIndex != -1) {
      refLine = line.substring(0, nullCharIndex);
      // String capabilities = line.substring(nullCharIndex + 1);
      // TODO: Parse capabilities if needed
    }

    final parts = refLine.split(' ');
    if (parts.length < 2) continue; // Not enough parts for oid and ref

    final oid = parts[0];
    final ref = parts[1];
    final r = <String, String>{'ref': ref, 'oid': oid};

    if (parts.length > 2) {
      for (int i = 2; i < parts.length; i++) {
        final attr = parts[i];
        final attrParts = attr.split(':');
        if (attrParts.length == 2) {
          if (attrParts[0] == 'symref-target') {
            r['target'] = attrParts[1];
          } else if (attrParts[0] == 'peeled') {
            r['peeled'] = attrParts[1];
          }
        }
      }
    }
    refs.add(r);
  }

  return refs;
}
