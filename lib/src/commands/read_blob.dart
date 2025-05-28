import '../utils/resolve_blob.dart';
import '../utils/resolve_filepath.dart';
import '../models/file_system.dart';

class ReadBlobResult {
  final String oid;
  final List<int> blob;

  ReadBlobResult({required this.oid, required this.blob});
}

Future<ReadBlobResult> readBlob({
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
  
  final blob = await resolveBlob(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: resolvedOid,
  );
  
  return blob;
}