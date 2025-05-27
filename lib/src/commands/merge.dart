import 'dart:io';

import '../commands/commit.dart';
import '../commands/current_branch.dart';
import '../commands/find_merge_base.dart';
import '../errors/fast_forward_error.dart';
import '../errors/merge_conflict_error.dart';
import '../errors/merge_not_supported_error.dart';
import '../managers/git_index_manager.dart';
import '../managers/git_ref_manager.dart';
import '../models/commit_author.dart';
import '../utils/abbreviate_ref.dart';
import '../utils/merge_tree.dart';

typedef SignCallback = Future<String> Function(String commit);
typedef MergeDriverCallback = Future<MergeDriverResult> Function(MergeDriverParams params);

class MergeResult {
  final String? oid;
  final bool alreadyMerged;
  final bool fastForward;
  final bool mergeCommit;
  final String? tree;

  MergeResult({
    this.oid,
    this.alreadyMerged = false,
    this.fastForward = false,
    this.mergeCommit = false,
    this.tree,
  });
}

Future<MergeResult> merge({
  required Directory fs,
  required dynamic cache,
  String? dir,
  required String gitdir,
  String? ours,
  required String theirs,
  bool fastForward = true,
  bool fastForwardOnly = false,
  bool dryRun = false,
  bool noUpdateBranch = false,
  bool abortOnConflict = true,
  String? message,
  required CommitAuthor author,
  required CommitAuthor committer,
  String? signingKey,
  SignCallback? onSign,
  MergeDriverCallback? mergeDriver,
}) async {
  ours ??= await currentBranch(fs: fs, gitdir: gitdir, fullname: true);
  ours = await GitRefManager.expand(fs: fs, gitdir: gitdir, ref: ours!);
  theirs = await GitRefManager.expand(fs: fs, gitdir: gitdir, ref: theirs);

  final ourOid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: ours);
  final theirOid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: theirs);

  final baseOids = await findMergeBase(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oids: [ourOid, theirOid],
  );

  if (baseOids.length != 1) {
    throw MergeNotSupportedError();
  }
  final baseOid = baseOids[0];

  if (baseOid == theirOid) {
    return MergeResult(oid: ourOid, alreadyMerged: true);
  }

  if (fastForward && baseOid == ourOid) {
    if (!dryRun && !noUpdateBranch) {
      await GitRefManager.writeRef(fs: fs, gitdir: gitdir, ref: ours, value: theirOid);
    }
    return MergeResult(oid: theirOid, fastForward: true);
  } else {
    if (fastForwardOnly) {
      throw FastForwardError();
    }

    final treeResult = await GitIndexManager.acquire(
      fs: fs,
      gitdir: gitdir,
      cache: cache,
      allowUnmerged: false,
      (index) async {
        return mergeTree(
          fs: fs,
          cache: cache,
          dir: dir,
          gitdir: gitdir,
          index: index,
          ourOid: ourOid,
          theirOid: theirOid,
          baseOid: baseOid,
          ourName: abbreviateRef(ours!),
          baseName: 'base',
          theirName: abbreviateRef(theirs),
          dryRun: dryRun,
          abortOnConflict: abortOnConflict,
          mergeDriver: mergeDriver,
        );
      },
    );

    if (treeResult is MergeConflictError) {
      throw treeResult;
    }
    final treeSha = treeResult as String;


    message ??= 'Merge branch '${abbreviateRef(theirs)}' into ${abbreviateRef(ours!)}';
    
    final commitOid = await commit(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      message: message,
      ref: ours,
      tree: treeSha,
      parents: [ourOid, theirOid],
      author: author,
      committer: committer,
      signingKey: signingKey,
      onSign: onSign,
      dryRun: dryRun,
      noUpdateBranch: noUpdateBranch,
    );

    return MergeResult(oid: commitOid, tree: treeSha, mergeCommit: true);
  }
} 