import '../commands/commit.dart' as _commit;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Create a new commit
///
/// Args:
///   fs: a file system implementation
///   onSign: a PGP signing implementation
///   dir: The [working tree](dir-vs-gitdir.md) directory path
///   gitdir: [required] The [git directory](dir-vs-gitdir.md) path
///   message: The commit message to use. Required, unless `amend == true`
///   author: The details about the author.
///   author.name: Default is `user.name` config.
///   author.email: Default is `user.email` config.
///   author.timestamp: Set the author timestamp field. This is the integer number of seconds since the Unix epoch (1970-01-01 00:00:00).
///   author.timezoneOffset: Set the author timezone offset field. This is the difference, in minutes, from the current timezone to UTC. Default is `(DateTime.now()).timeZoneOffset.inMinutes`.
///   committer: The details about the commit committer, in the same format as the author parameter. If not specified, the author details are used.
///   committer.name: Default is `user.name` config.
///   committer.email: Default is `user.email` config.
///   committer.timestamp: Set the committer timestamp field. This is the integer number of seconds since the Unix epoch (1970-01-01 00:00:00).
///   committer.timezoneOffset: Set the committer timezone offset field. This is the difference, in minutes, from the current timezone to UTC. Default is `(DateTime.now()).timeZoneOffset.inMinutes`.
///   signingKey: Sign the tag object using this private PGP key.
///   amend: If true, replaces the last commit pointed to by `ref` with a new commit.
///   dryRun: If true, simulates making a commit so you can test whether it would succeed. Implies `noUpdateBranch`.
///   noUpdateBranch: If true, does not update the branch pointer after creating the commit.
///   ref: The fully expanded name of the branch to commit to. Default is the current branch pointed to by HEAD. (TODO: fix it so it can expand branch names without throwing if the branch doesn't exist yet.)
///   parent: The SHA-1 object ids of the commits to use as parents. If not specified, the commit pointed to by `ref` is used.
///   tree: The SHA-1 object id of the tree to use. If not specified, a new tree object is created from the current git index.
///   cache: a [cache](cache.md) object
///
/// Returns:
///   Resolves successfully with the SHA-1 object id of the newly created commit.
///
/// Example:
/// ```dart
/// var sha = await Git.commit(
///   fs: fs,
///   dir: '/tutorial',
///   author: {
///     'name': 'Mr. Test',
///     'email': 'mrtest@example.com',
///   },
///   message: 'Added the a.txt file',
/// );
/// print(sha);
/// ```
Future<String> commit({
  required FsClient fs,
  SignCallback? onSign,
  String? dir,
  String? gitdir,
  String? message,
  Author? author,
  Author? committer,
  String? signingKey,
  bool amend = false,
  bool dryRun = false,
  bool noUpdateBranch = false,
  String? ref,
  List<String>? parent,
  String? tree,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    if (!amend) {
      assertParameter('message', message);
    }
    if (signingKey != null) {
      assertParameter('onSign', onSign);
    }
    final fsModel = FileSystem(fs);
    final effectiveGitdir = gitdir ?? join(dir!, '.git');

    return await _commit.commit(
      fs: fsModel,
      cache: cache,
      onSign: onSign,
      gitdir: effectiveGitdir,
      message: message,
      author: author,
      committer: committer,
      signingKey: signingKey,
      amend: amend,
      dryRun: dryRun,
      noUpdateBranch: noUpdateBranch,
      ref: ref,
      parent: parent,
      tree: tree,
    );
  } catch (err) {
    // TODO: Fix this throw
    // err.caller = 'git.commit';
    rethrow;
  }
}

class Author {
  String? name;
  String? email;
  int? timestamp;
  int? timezoneOffset;

  Author({this.name, this.email, this.timestamp, this.timezoneOffset});
}
