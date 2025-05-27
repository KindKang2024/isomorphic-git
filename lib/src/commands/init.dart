import 'dart:io';
import 'package:path/path.dart' as p;

/// Initialize a new repository
Future<void> init({
  required Directory fs,
  bool bare = false,
  String? dir,
  String? gitdir,
  String defaultBranch = 'master',
}) async {
  final gitDirectory = bare ? Directory(dir!) : Directory(p.join(dir!, '.git'));
  if (gitdir != null) {
    gitDirectory.path = gitdir;
  }

  // Don't overwrite an existing config
  if (await File(p.join(gitDirectory.path, 'config')).exists()) return;

  var folders = [
    'hooks',
    'info',
    'objects/info',
    'objects/pack',
    'refs/heads',
    'refs/tags',
  ];
  folders = folders.map((folder) => p.join(gitDirectory.path, folder)).toList();
  for (final folder in folders) {
    await Directory(folder).create(recursive: true);
  }

  await File(p.join(gitDirectory.path, 'config')).writeAsString(
    '[core]\n'
    '\trepositoryformatversion = 0\n'
    '\tfilemode = false\n'
    '\tbare = $bare\n'
    '${bare ? '' : '\tlogallrefupdates = true\n'}'
    '\tsymlinks = false\n'
    '\tignorecase = true\n',
  );
  await File(
    p.join(gitDirectory.path, 'HEAD'),
  ).writeAsString('ref: refs/heads/$defaultBranch\n');
}
