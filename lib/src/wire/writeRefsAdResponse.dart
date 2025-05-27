import 'dart:typed_data';

import '../models/git_pkt_line.dart';
import '../utils/pkg.dart';

Future<List<Uint8List>> writeRefsAdResponse({
  required Set<String> capabilities,
  required Map<String, String> refs,
  required Map<String, String> symrefs,
}) async {
  final stream = <Uint8List>[];

  // Compose capabilities string
  String syms = '';
  symrefs.forEach((key, value) {
    syms += 'symref=$key:$value ';
  });

  String caps = '\x00${capabilities.join(' ')} ${syms}agent=${pkg.agent}';

  // Note: In the edge case of a brand new repo, zero refs (and zero capabilities)
  // are returned.
  refs.forEach((key, value) {
    stream.add(GitPktLine.encode('$value $key$caps\n'));
    caps = '';
  });

  stream.add(GitPktLine.flush());
  return stream;
}
