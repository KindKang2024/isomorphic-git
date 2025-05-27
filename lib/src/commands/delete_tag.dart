import 'dart:async';

import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';

/// Delete a local tag ref
Future<void> deleteTag({
  required FileSystem fs,
  required String gitdir,
  required String ref, // The tag to delete
}) async {
  ref = ref.startsWith('refs/tags/') ? ref : 'refs/tags/$ref';
  await GitRefManager.deleteRef(fs: fs, gitdir: gitdir, ref: ref);
}
