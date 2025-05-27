import 'dart:async';
import 'dart:convert';

Future<Map<String, dynamic>> parseCapabilitiesV2(
  Stream<List<int>> stream,
) async {
  final capabilities2 = <String, dynamic>{};
  final lines = stream.transform(utf8.decoder).transform(const LineSplitter());

  await for (String line in lines) {
    if (line.isEmpty) continue;

    final i = line.indexOf('=');
    if (i > -1) {
      final key = line.substring(0, i);
      final value = line.substring(i + 1);
      capabilities2[key] = value;
    } else {
      capabilities2[line] = true;
    }
  }
  return {'protocolVersion': 2, 'capabilities2': capabilities2};
}
