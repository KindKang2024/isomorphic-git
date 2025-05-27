import 'dart:async';

import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/abbreviate_ref.dart';

Future<String?> currentBranch({
  required FileSystem fs,
  required String gitdir,
  bool fullname = false,
  bool test = false,
}) async {
  final ref = await GitRefManager.resolve(
    fs: fs,
    gitdir: gitdir,
    ref: 'HEAD',
    depth: 2,
  );

  if (test) {
    try {
      await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: ref);
    } catch (_) {
      return null;
    }
  }

  // Return null for detached HEAD
  if (!ref.startsWith('refs/')) return null;
  return fullname ? ref : abbreviateRef(ref);
}
