import 'package:clean_git_ref/clean_git_ref.dart' as clean_git_ref;

import '../errors/already_exists_error.dart';
import '../errors/invalid_ref_name_error.dart';
import '../managers/git_config_manager.dart';
import '../models/fs.dart'; // Assuming FsModel exists

Future<void> addRemote({
  required FsModel fs,
  required String gitdir,
  required String remote,
  required String url,
  bool force = false, // Defaulting force to false as in the JS version
}) async {
  if (remote != clean_git_ref.clean(remote)) {
    throw InvalidRefNameError(remote, clean_git_ref.clean(remote));
  }
  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
  if (!force) {
    final remoteNames = await config.getSubsections('remote');
    if (remoteNames.contains(remote)) {
      final existingUrl = await config.get('remote.$remote.url');
      if (url != existingUrl) {
        throw AlreadyExistsError('remote', remote);
      }
    }
  }
  await config.set('remote.$remote.url', url);
  await config.set(
    'remote.$remote.fetch',
    '+refs/heads/*:refs/remotes/$remote/*',
  );
  await GitConfigManager.save(fs: fs, gitdir: gitdir, config: config);
}
