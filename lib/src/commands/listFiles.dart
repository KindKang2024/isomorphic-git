import 'dart:io';

import '../commands/read_tree.dart';
import '../managers/git_index_manager.dart';
import '../managers/git_ref_manager.dart';
import 'package:path/path.dart' as p;

Future<List<String>> listFiles({
  required Directory fs,
  required dynamic cache,
  required String gitdir,
  String? ref,
}) async {
  if (ref != null) {
    final oid = await GitRefManager.resolve(gitdir: gitdir, fs: fs, ref: ref);
    final filenames = <String>[];
    await _accumulateFilesFromOid(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: oid,
      filenames: filenames,
      prefix: '',
    );
    return filenames;
  } else {
    return GitIndexManager.acquire(fs: fs, gitdir: gitdir, cache: cache, (
      index,
    ) {
      return index.entries.map((x) => x.path).toList();
    });
  }
}

Future<void> _accumulateFilesFromOid({
  required Directory fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  required List<String> filenames,
  required String prefix,
}) async {
  final treeResult = await readTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  for (final entry in treeResult.tree) {
    if (entry.type == 'tree') {
      await _accumulateFilesFromOid(
        fs: fs,
        cache: cache,
        gitdir: gitdir,
        oid: entry.oid,
        filenames: filenames,
        prefix: p.join(prefix, entry.path),
      );
    } else {
      filenames.add(p.join(prefix, entry.path));
    }
  }
}
