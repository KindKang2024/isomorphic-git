import '../commands/current_branch.dart';
import '../errors/already_exists_error.dart';
import '../errors/invalid_ref_name_error.dart';
import '../managers/git_ref_manager.dart';
import '../utils/clean_git_ref.dart'; // Assuming a Dart equivalent

// TODO: Define these types or import them
typedef FileSystem = dynamic; // Placeholder

Future<void> renameBranch({
  required FileSystem fs,
  required String gitdir,
  required String oldref, // Short name of the old branch
  required String ref, // Short name of the new branch
  bool checkout = false,
}) async {
  // Validate ref names
  if (ref != cleanGitRef(ref)) {
    throw InvalidRefNameError(refName: ref, suggestion: cleanGitRef(ref));
  }
  if (oldref != cleanGitRef(oldref)) {
    throw InvalidRefNameError(refName: oldref, suggestion: cleanGitRef(oldref));
  }

  final String fullOldRef = 'refs/heads/$oldref';
  final String fullNewRef = 'refs/heads/$ref';

  // Check if the new branch name already exists
  final bool newRefExists = await GitRefManager.exists(
    fs: fs,
    gitdir: gitdir,
    ref: fullNewRef,
  );
  if (newRefExists) {
    throw AlreadyExistsError(type: 'branch', name: ref, canForce: false);
  }

  // Resolve the OID of the old branch
  final String oidToPointTo = await GitRefManager.resolve(
    fs: fs,
    gitdir: gitdir,
    ref: fullOldRef,
    depth:
        1, // In JS, depth: 1 is used. Ensure resolve supports this or behaves correctly.
  );

  // Create the new branch ref pointing to the same OID
  await GitRefManager.writeRef(
    fs: fs,
    gitdir: gitdir,
    ref: fullNewRef,
    value: oidToPointTo,
  );

  // Delete the old branch ref
  await GitRefManager.deleteRef(fs: fs, gitdir: gitdir, ref: fullOldRef);

  // Check if the renamed branch was the current branch
  String? currentBranchFullName;
  try {
    currentBranchFullName = await currentBranch(
      fs: fs,
      gitdir: gitdir,
      fullname: true,
    );
  } catch (e) {
    // It might throw if no current branch (e.g. detached HEAD), that's okay.
    // We only care if it *was* the branch we are renaming.
  }

  final bool wasCurrentBranch = currentBranchFullName == fullOldRef;

  // If checkout is true OR if the renamed branch was the current one, update HEAD
  if (checkout || wasCurrentBranch) {
    await GitRefManager.writeSymbolicRef(
      fs: fs,
      gitdir: gitdir,
      ref: 'HEAD',
      value: fullNewRef,
    );
  }
}
