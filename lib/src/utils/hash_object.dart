import '../models/git_object.dart';
import 'shasum.dart';
import 'dart:typed_data';

Future<String> hashObject({
  required String gitdir,
  required String type,
  required Uint8List object,
}) async {
  return shasum(GitObject.wrap(type: type, object: object));
}
