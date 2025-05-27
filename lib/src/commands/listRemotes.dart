import 'dart:io';

import '../managers/git_config_manager.dart';

class GitRemote {
  String remote;
  String url;
  GitRemote({required this.remote, required this.url});
}

Future<List<GitRemote>> listRemotes({
  required Directory fs,
  required String gitdir,
}) async {
  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
  final remoteNames = await config.getSubsections('remote');
  final remotes = await Future.wait(
    remoteNames.map((remote) async {
      final url = await config.get('remote.$remote.url');
      return GitRemote(remote: remote, url: url!);
    }),
  );
  return remotes;
}
