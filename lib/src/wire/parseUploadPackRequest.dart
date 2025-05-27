import '../models/git_pkt_line.dart';

Future<Map<String, dynamic>> parseUploadPackRequest(
  Stream<List<int>> stream,
) async {
  final read = GitPktLine.streamReader(stream);
  bool done = false;
  List<String>? capabilities;
  final wants = <String>[];
  final haves = <String>[];
  final shallows = <String>[];
  int? depth;
  int? since;
  final exclude = <String>[];
  bool relative = false;

  while (!done) {
    final line = await read();
    if (line == true) break;
    if (line == null) continue;

    final parts = GitPktLine.decode(line as List<int>).trim().split(' ');
    final key = parts[0];
    final value = parts.length > 1 ? parts[1] : null;

    if (capabilities == null && parts.length > 2) {
      capabilities = parts.sublist(2);
    } else if (capabilities == null &&
        parts.length > 1 &&
        key != 'want' &&
        key != 'have' &&
        key != 'shallow' &&
        key != 'deepen' &&
        key != 'deepen-since' &&
        key != 'deepen-not' &&
        key != 'deepen-relative' &&
        key != 'done') {
      capabilities = parts.sublist(1);
    }

    switch (key) {
      case 'want':
        if (value != null) wants.add(value);
        break;
      case 'have':
        if (value != null) haves.add(value);
        break;
      case 'shallow':
        if (value != null) shallows.add(value);
        break;
      case 'deepen':
        if (value != null) depth = int.parse(value);
        break;
      case 'deepen-since':
        if (value != null) since = int.parse(value);
        break;
      case 'deepen-not':
        if (value != null) exclude.add(value);
        break;
      case 'deepen-relative':
        relative = true;
        break;
      case 'done':
        done = true;
        break;
    }
  }

  return {
    'capabilities': capabilities,
    'wants': wants,
    'haves': haves,
    'shallows': shallows,
    'depth': depth,
    'since': since,
    'exclude': exclude,
    'relative': relative,
    'done': done,
  };
}
