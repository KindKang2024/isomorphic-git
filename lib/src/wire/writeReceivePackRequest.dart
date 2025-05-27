import 'dart:typed_data';

import '../models/git_pkt_line.dart';

class Triplet {
  final String oldoid;
  final String oid;
  final String fullRef;

  Triplet({required this.oldoid, required this.oid, required this.fullRef});
}

Future<List<Uint8List>> writeReceivePackRequest({
  List<String> capabilities = const [],
  List<Triplet> triplets = const [],
}) async {
  final packstream = <Uint8List>[];
  String capsFirstLine = '\x00 ${capabilities.join(' ')}';

  for (final trip in triplets) {
    packstream.add(
      GitPktLine.encode(
        '${trip.oldoid} ${trip.oid} ${trip.fullRef}$capsFirstLine\n',
      ),
    );
    capsFirstLine = '';
  }
  packstream.add(GitPktLine.flush());
  return packstream;
}
