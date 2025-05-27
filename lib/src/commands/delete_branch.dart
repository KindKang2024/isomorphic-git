import 'dart:async';

import '../commands/current_branch.dart';
import '../errors/not_found_error.dart';
import '../managers/git_config_manager.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/abbreviate_ref.dart';

Future<void> deleteBranch({
  required FileSystem fs,
  required String gitdir,
  required String ref,
}) async {
  ref = ref.startsWith('refs/heads/') ? ref : 'refs/heads/$ref';
  final exist = await GitRefManager.exists(fs: fs, gitdir: gitdir, ref: ref);
  if (!exist) {
    throw NotFoundError(ref);
  }

  final fullRef = await GitRefManager.expand(fs: fs, gitdir: gitdir, ref: ref);
  final currentRef = await currentBranch(
    fs: fs,
    gitdir: gitdir,
    fullname: true,
  );
  if (fullRef == currentRef) {
    // detach HEAD
    final value = await GitRefManager.resolve(
      fs: fs,
      gitdir: gitdir,
      ref: fullRef,
    );
    await GitRefManager.writeRef(
      fs: fs,
      gitdir: gitdir,
      ref: 'HEAD',
      value: value,
    );
  }

  // Delete a specified branch
  await GitRefManager.deleteRef(fs: fs, gitdir: gitdir, ref: fullRef);

  // Delete branch config entries
  final abbrevRef = abbreviateRef(ref);
  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
  await config.deleteSection('branch', abbrevRef);
  await GitConfigManager.save(fs: fs, gitdir: gitdir, config: config);
}
