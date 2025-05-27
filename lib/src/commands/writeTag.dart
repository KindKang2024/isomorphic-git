import 'dart:async';

import 'package:../models/git_annotated_tag.dart';
import 'package:../storage/write_object.dart';

// Assuming FileSystem and TagObject are defined elsewhere.
// For now, using `dynamic` and `Map<String, dynamic>` as placeholders.
// import '../models/file_system.dart';
// import '../models/tag_object.dart'; // Or a more specific type if available

Future<String> writeTag({
  required dynamic fs, // FileSystem fs,
  required String gitdir,
  required Map<String, dynamic> tag, // TagObject tag,
}) async {
  // Convert object to buffer
  final object = GitAnnotatedTag.from(tag).toObject();
  final oid = await writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'tag',
    object: object,
    format: 'content',
  );
  return oid;
}
