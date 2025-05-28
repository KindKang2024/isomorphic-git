import '../utils/resolve_commit.dart';
import '../models/file_system.dart';

class ReadCommitResult {
  final String oid;
  final Map<String, dynamic> commit;
  final String payload;

  ReadCommitResult({
    required this.oid,
    required this.commit,
    required this.payload,
  });
}

Future<ReadCommitResult> readCommit({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
}) async {
  final result = await resolveCommit(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  
  return ReadCommitResult(
    oid: result.oid,
    commit: result.commit.parse(),
    payload: result.commit.withoutSignature(),
  );
}