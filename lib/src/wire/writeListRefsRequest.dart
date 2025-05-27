import 'dart:typed_data';

import '../models/git_pkt_line.dart';
import '../utils/pkg.dart';

Future<List<Uint8List>> writeListRefsRequest({
  String? prefix,
  bool symrefs = false,
  bool peelTags = false,
}) async {
  final packstream = <Uint8List>[];

  // command
  packstream.add(GitPktLine.encode('command=ls-refs\n'));

  // capability-list
  packstream.add(GitPktLine.encode('agent=${pkg.agent}\n'));

  // [command-args]
  if (peelTags || symrefs || prefix != null) {
    packstream.add(GitPktLine.delim());
  }
  if (peelTags) packstream.add(GitPktLine.encode('peel'));
  if (symrefs) packstream.add(GitPktLine.encode('symrefs'));
  if (prefix != null) packstream.add(GitPktLine.encode('ref-prefix $prefix'));

  packstream.add(GitPktLine.flush());
  return packstream;
}
