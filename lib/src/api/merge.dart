import '../commands/merge.dart' as commands;
import '../errors/missing_name_error.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/normalize_author_object.dart';
import '../utils/normalize_committer_object.dart';
import '../typedefs.dart'; // Assuming SignCallback, MergeDriverCallback are defined here

class MergeResult {
  final String? oid;
  final bool? alreadyMerged;
  final bool? fastForward;
  final bool? mergeCommit;
  final String? tree;

  MergeResult({
    this.oid,
    this.alreadyMerged,
    this.fastForward,
    this.mergeCommit,
    this.tree,
  });

  factory MergeResult.fromMap(Map<String, dynamic> map) {
    return MergeResult(
      oid: map['oid'],
      alreadyMerged: map['alreadyMerged'],
      fastForward: map['fastForward'],
      mergeCommit: map['mergeCommit'],
      tree: map['tree'],
    );
  }
}

/// Merge two branches
Future<MergeResult> merge({
  required FileSystem fs,
  SignCallback? onSign,
  String? dir,
  String? gitdir,
  String? ours,
  required String theirs,
  bool fastForward = true,
  bool fastForwardOnly = false,
  bool dryRun = false,
  bool noUpdateBranch = false,
  bool abortOnConflict = true,
  String? message,
  Author? authorInput,
  Committer? committerInput,
  String? signingKey,
  Map<String, dynamic> cache = const {},
  MergeDriverCallback? mergeDriver,
}) async {
  try {
    assertParameter('fs', fs);
    if (signingKey != null) {
      assertParameter('onSign', onSign);
    }

    gitdir ??= join(dir, '.git');

    final author = await normalizeAuthorObject(
      fs: fs,
      gitdir: gitdir,
      author: authorInput,
    );
    if (author == null && (!fastForwardOnly || !fastForward)) {
      throw MissingNameError('author');
    }

    final committer = await normalizeCommitterObject(
      fs: fs,
      gitdir: gitdir,
      author: author,
      committer: committerInput,
    );
    if (committer == null && (!fastForwardOnly || !fastForward)) {
      throw MissingNameError('committer');
    }

    var result = await commands.merge(
      fs: FileSystem(fs.client),
      cache: cache,
      dir: dir,
      gitdir: gitdir,
      ours: ours,
      theirs: theirs,
      fastForward: fastForward,
      fastForwardOnly: fastForwardOnly,
      dryRun: dryRun,
      noUpdateBranch: noUpdateBranch,
      abortOnConflict: abortOnConflict,
      message: message,
      author: author,
      committer: committer,
      signingKey: signingKey,
      onSign: onSign,
      mergeDriver: mergeDriver,
    );
    return MergeResult.fromMap(result);
  } catch (err) {
    //TODO: err.caller = 'git.merge';
    rethrow;
  }
}
