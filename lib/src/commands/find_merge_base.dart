import 'dart:async';
import 'dart:typed_data';

import '../models/file_system.dart';
import '../models/git_commit.dart';
import '../storage/read_object.dart';

class _HeadInfo {
  final int index;
  final String oid;
  _HeadInfo({required this.index, required this.oid});
}

Future<List<String>> findMergeBase({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required List<String> oids,
}) async {
  final visits = <String, Set<int>>{};
  final passes = oids.length;
  var heads = oids
      .asMap()
      .entries
      .map((entry) => _HeadInfo(index: entry.key, oid: entry.value))
      .toList();

  while (heads.isNotEmpty) {
    final result = <String>{};
    for (final head in heads) {
      visits.putIfAbsent(head.oid, () => <int>{});
      visits[head.oid]!.add(head.index);
      if (visits[head.oid]!.length == passes) {
        result.add(head.oid);
      }
    }

    if (result.isNotEmpty) {
      return result.toList();
    }

    final newHeads = <String, _HeadInfo>{};
    for (final head in heads) {
      try {
        final objectResult = await readObject(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          oid: head.oid,
        );
        final commit = GitCommit.fromBuffer(objectResult.object as Uint8List);
        final parents = commit.parseHeaders().parent;
        for (final parentOid in parents) {
          if (!visits.containsKey(parentOid) ||
              !visits[parentOid]!.contains(head.index)) {
            newHeads['$parentOid:${head.index}'] = _HeadInfo(
              oid: parentOid,
              index: head.index,
            );
          }
        }
      } catch (_) {
        // do nothing
      }
    }
    heads = newHeads.values.toList();
  }
  return [];
}
