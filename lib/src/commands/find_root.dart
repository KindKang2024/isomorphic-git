import 'dart:async';

import '../errors/not_found_error.dart';
import '../models/file_system.dart';
import '../utils/dirname.dart';
import '../utils/join.dart';

/// Find the root git directory
///
/// Starting at `filepath`, walks upward until it finds a directory that contains a subdirectory called '.git'.
Future<String> findRoot({
  required FileSystem fs,
  required String filepath,
}) async {
  if (await fs.exists(join(filepath, '.git'))) {
    return filepath;
  } else {
    final parent = dirname(filepath);
    if (parent == filepath) {
      throw NotFoundError('git root for $filepath');
    }
    return findRoot(fs: fs, filepath: parent);
  }
}
