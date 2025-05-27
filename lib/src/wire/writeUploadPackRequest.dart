import 'dart:typed_data';

import '../models/git_pkt_line.dart';

List<Uint8List> writeUploadPackRequest({
  List<String> capabilities = const [],
  List<String> wants = const [],
  List<String> haves = const [],
  List<String> shallows = const [],
  int? depth,
  DateTime? since,
  List<String> exclude = const [],
}) {
  final packstream = <Uint8List>[];
  // remove duplicates by converting to a Set and back to a List
  wants = wants.toSet().toList();

  String firstLineCapabilities = ' ${capabilities.join(' ')}';
  for (final oid in wants) {
    packstream.add(GitPktLine.encode('want $oid$firstLineCapabilities\n'));
    firstLineCapabilities = '';
  }
  for (final oid in shallows) {
    packstream.add(GitPktLine.encode('shallow $oid\n'));
  }
  if (depth != null) {
    packstream.add(GitPktLine.encode('deepen $depth\n'));
  }
  if (since != null) {
    packstream.add(
      GitPktLine.encode(
        'deepen-since ${since.millisecondsSinceEpoch ~/ 1000}\n',
      ),
    );
  }
  for (final oid in exclude) {
    packstream.add(GitPktLine.encode('deepen-not $oid\n'));
  }
  packstream.add(GitPktLine.flush());
  for (final oid in haves) {
    packstream.add(GitPktLine.encode('have $oid\n'));
  }
  packstream.add(GitPktLine.encode('done\n'));
  return packstream;
}
