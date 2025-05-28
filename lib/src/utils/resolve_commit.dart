import '../errors/object_type_error.dart';
import '../models/git_annotated_tag.dart';
import '../models/git_commit.dart';
import '../storage/read_object.dart' as read_object;
import '../models/file_system.dart';

class ResolveCommitResult {
  final GitCommit commit;
  final String oid;
  ResolveCommitResult({required this.commit, required this.oid});
}

Future<ResolveCommitResult> resolveCommit({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
}) async {
  var result = await read_object.readObject(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  var type = result.type;
  var object = result.object;

  if (type == 'tag') {
    oid = GitAnnotatedTag.from(object).parse()['object'];
    return resolveCommit(fs: fs, cache: cache, gitdir: gitdir, oid: oid);
  }

  if (type != 'commit') {
    throw ObjectTypeError(oid: oid, actual: type, expected: 'commit');
  }

  return ResolveCommitResult(commit: GitCommit.from(object), oid: oid);
}
