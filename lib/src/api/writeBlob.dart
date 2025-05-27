import 'dart:async';
import 'dart:typed_data';

import '../models/file_system.dart';
import '../storage/write_object.dart' as write_object;
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

Future<String> writeBlob({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required Uint8List blob,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('blob', blob);

    return await write_object.writeObject(
      fs: FileSystem(fs),
      gitdir: gitdir,
      type: 'blob',
      object: blob,
      format: 'content',
    );
  } catch (err) {
    // err.caller = 'git.writeBlob'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
