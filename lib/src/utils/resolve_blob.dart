import 'dart:typed_data';

import '../errors/object_type_error.dart';
import '../models/git_annotated_tag.dart';
import '../storage/read_object.dart' ;
import '../models/file_system.dart';

class ResolveBlobResult {
  final String oid;
  final Uint8List blob;
  ResolveBlobResult({required this.oid, required this.blob});
}

Future<ResolveBlobResult> resolveBlob({
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
    return resolveBlob(fs: fs, cache: cache, gitdir: gitdir, oid: oid);
  }

  if (type != 'blob') {
    throw ObjectTypeError(oid: oid, actual: type, expected: 'blob');
  }

  return ResolveBlobResult(
    oid: oid,
    blob: Uint8List.fromList(object as List<int>),
  );
}
