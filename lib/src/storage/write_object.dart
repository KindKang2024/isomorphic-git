import 'dart:typed_data';

import '../models/git_object.dart';
import '../storage/write_object_loose.dart';
import '../utils/deflate.dart';
import '../utils/shasum.dart';
import '../utils/fs.dart'; // Assuming FileSystem is defined here

Future<String> writeObject({
  required FileSystem fs,
  required String gitdir,
  required String type,
  required Uint8List object,
  String format = 'content',
  String? oid,
  bool dryRun = false,
}) async {
  Uint8List processedObject = object;

  if (format != 'deflated') {
    if (format != 'wrapped') {
      processedObject = GitObject.wrap(type: type, object: object);
    }
    oid = await shasum(processedObject);
    // Assuming deflate returns Uint8List
    processedObject = await deflate(processedObject);
  }

  if (oid == null) {
    // This case should ideally not be reached if format is 'deflated' without an oid.
    // Or, shasum should be called even for 'deflated' if oid is not provided.
    // For safety, calculate shasum if oid is null. This might differ from original JS if oid was expected for 'deflated'.
    processedObject = GitObject.wrap(
      type: type,
      object: object,
    ); // ensure it's wrapped before shasum
    oid = await shasum(processedObject);
    // And then deflate again if not already deflated
    if (format != 'deflated') {
      processedObject = await deflate(processedObject);
    }
  }

  if (!dryRun) {
    await writeObjectLoose(
      fs: fs,
      gitdir: gitdir,
      object: processedObject,
      // original JS passes format: 'deflated' here, implying object is always deflated before this call
      // if processedObject is not guaranteed to be deflated, this needs adjustment or ensure deflate runs.
      format: 'deflated',
      oid: oid,
    );
  }
  return oid!;
}
