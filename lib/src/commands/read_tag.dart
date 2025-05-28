import '../errors/object_type_error.dart';
import '../models/git_annotated_tag.dart';
import '../models/file_system.dart';
import '../storage/read_object.dart';

class ReadTagResult {
  final String oid;
  final Map<String, dynamic> tag;
  final String payload;

  ReadTagResult({
    required this.oid,
    required this.tag,
    required this.payload,
  });
}

Future<ReadTagResult> readTag({
  required FileSystem fs,
  required dynamic cache,
  required String gitdir,
  required String oid,
}) async {
  final result = await readObject(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
    format: 'content',
  );
  
  if (result.type != 'tag') {
    throw ObjectTypeError(oid, result.type, 'tag');
  }
  
  final tag = GitAnnotatedTag.from(result.object);
  
  return ReadTagResult(
    oid: oid,
    tag: tag.parse(),
    payload: tag.payload(),
  );
}