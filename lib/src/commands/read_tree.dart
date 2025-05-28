import '../utils/resolve_filepath.dart';
import '../utils/resolve_tree.dart';
import '../models/file_system.dart';

class ReadTreeResult {
  final String oid;
  final List<dynamic> tree;

  ReadTreeResult({required this.oid, required this.tree});
}

Future<ReadTreeResult> readTree({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
  String? filepath,
}) async {
  String resolvedOid = oid;
  if (filepath != null) {
    resolvedOid = await resolveFilepath(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: oid,
      filepath: filepath,
    );
  }
  
  final result = await resolveTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: resolvedOid,
  );
  
  return ReadTreeResult(
    oid: result.oid,
    tree: result.tree.entries(),
  );
}