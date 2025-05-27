import 'dart:async';

import '../commands/write_tag.dart' as command_write_tag;
import '../models/file_system.dart';
import '../models/git_annotated_tag.dart'; // Assuming GitAnnotatedTag model for TagObject
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

// typedef TagObject = Map<String, dynamic>; // From JS, represented by GitAnnotatedTag in Dart

Future<String> writeTag({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required GitAnnotatedTag tag, // Using the strongly-typed Dart model
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('tag', tag);

    return await command_write_tag.writeTag(
      fs: FileSystem(fs),
      gitdir: gitdir,
      tag: tag, // Pass the Dart object directly
    );
  } catch (err) {
    // err.caller = 'git.writeTag'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
