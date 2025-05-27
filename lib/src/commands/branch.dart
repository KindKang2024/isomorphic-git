import 'dart:async';

import 'package:clean_git_ref/clean_git_ref.dart' as clean_git_ref;

import '../errors/already_exists_error.dart';
import '../errors/invalid_ref_name_error.dart';
import '../managers/git_ref_manager.dart';
import '../models/fs.dart'; // Assuming FsModel exists

Future<void> branch({
  required FsModel fs,
  required String gitdir,
  required String ref,
  String?
  object, // Corresponds to 'object' in JS, can be a commit OID or ref name
  bool checkout = false,
  bool force = false,
}) async {
  if (ref != clean_git_ref.clean(ref)) {
    throw InvalidRefNameError(ref, clean_git_ref.clean(ref));
  }

  final fullref = 'refs/heads/$ref';

  if (!force) {
    final exist = await GitRefManager.exists(
      fs: fs,
      gitdir: gitdir,
      ref: fullref,
    );
    if (exist) {
      // The third parameter `canForce` for AlreadyExistsError is not directly mapped here.
      // Dart typically doesn't include such a boolean directly in the error constructor.
      // If this behavior is critical, the error class or handling might need adjustment.
      throw AlreadyExistsError('branch', ref);
    }
  }

  String? oid;
  try {
    oid = await GitRefManager.resolve(
      fs: fs,
      gitdir: gitdir,
      ref: object ?? 'HEAD',
    );
  } catch (e) {
    // Probably an empty repo, or ref not found. oid remains null.
    // Consider logging this error or handling it more specifically if needed.
  }

  // Create a new ref that points at the current commit
  if (oid != null) {
    await GitRefManager.writeRef(
      fs: fs,
      gitdir: gitdir,
      ref: fullref,
      value: oid,
    );
  }

  if (checkout) {
    // Update HEAD
    await GitRefManager.writeSymbolicRef(
      fs: fs,
      gitdir: gitdir,
      ref: 'HEAD',
      value: fullref,
    );
  }
}
