import '../commands/current_branch.dart';
import '../errors/already_exists_error.dart';
import '../errors/invalid_ref_name_error.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/clean_git_ref.dart';

Future<void> renameBranch({
  required FileSystem fs,
  required String gitdir,
  required String oldref,
  required String ref,
  bool checkout = false,
}) async {
  if (ref != cleanGitRef(ref)) {
    throw InvalidRefNameError(ref, cleanGitRef(ref));
  }

  if (oldref != cleanGitRef(oldref)) {
    throw InvalidRefNameError(oldref, cleanGitRef(oldref));
  }

  final fulloldref = 'refs/heads/$oldref';
  final fullnewref = 'refs/heads/$ref';

  final newexist = await GitRefManager.exists(
    fs: fs,
    gitdir: gitdir,
    ref: fullnewref,
  );

  if (newexist) {
    throw AlreadyExistsError('branch', ref, false);
  }

  final value = await GitRefManager.resolve(
    fs: fs,
    gitdir: gitdir,
    ref: fulloldref,
    depth: 1,
  );

  await GitRefManager.writeRef(
    fs: fs,
    gitdir: gitdir,
    ref: fullnewref,
    value: value,
  );
  
  await GitRefManager.deleteRef(
    fs: fs,
    gitdir: gitdir,
    ref: fulloldref,
  );

  final fullCurrentBranchRef = await currentBranch(
    fs: fs,
    gitdir: gitdir,
    fullname: true,
  );
  
  final isCurrentBranch = fullCurrentBranchRef == fulloldref;

  if (checkout || isCurrentBranch) {
    // Update HEAD
    await GitRefManager.writeSymbolicRef(
      fs: fs,
      gitdir: gitdir,
      ref: 'HEAD',
      value: fullnewref,
    );
  }
}