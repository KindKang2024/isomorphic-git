import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import 'read_blob.dart';

Future<List<int>> readNote({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  String ref = 'refs/notes/commits',
  required String oid,
}) async {
  final parent = await GitRefManager.resolve(
    gitdir: gitdir,
    fs: fs,
    ref: ref,
  );
  
  final result = await readBlob(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: parent,
    filepath: oid,
  );
  
  return result.blob;
}