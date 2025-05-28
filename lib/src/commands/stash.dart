import 'dart:async';

import '../errors/not_found_error.dart';
import '../managers/git_ref_manager.dart';
import '../managers/git_stash_manager.dart';
import '../utils/walker_to_tree_entry_map.dart';

import '../api/checkout.dart';
import '../api/read_commit.dart';
import './STAGE.dart';
import './TREE.dart';
import './current_branch.dart';
import './read_commit.dart' as internal_read_commit;

Future<String> stashPush({
  required FileSystem fs,
  required String dir,
  required String gitdir,
  String message = '',
}) async {
  final stashMgr = GitStashManager(fs: fs, dir: dir, gitdir: gitdir);

  await stashMgr.getAuthor(); // ensure there is an author
  final branch = await currentBranch(fs: fs, gitdir: gitdir, fullname: false);

  // prepare the stash commit: first parent is the current branch HEAD
  final headCommit = await GitRefManager.resolve(
    fs: fs,
    gitdir: gitdir,
    ref: 'HEAD',
  );

  final headCommitObj = await readCommit(
    fs: fs,
    dir: dir,
    gitdir: gitdir,
    oid: headCommit,
  );
  final headMsg = headCommitObj.commit.message;

  var stashCommitParents = [headCommit];
  String? stashCommitTree;
  var workDirCompareBase = TREE(ref: 'HEAD');

  final indexTree = await writeTreeChanges(
    fs: fs,
    dir: dir,
    gitdir: gitdir,
    treePair: [
      TREE(ref: 'HEAD'),
      'stage',
    ],
  );
  if (indexTree != null) {
    // this indexTree will be the tree of the stash commit
    // create a commit from the index tree, which has one parent, the current branch HEAD
    final stashCommitOne = await stashMgr.writeStashCommit(
      message:
          'stash-Index: WIP on $branch - ${DateTime.now().toIso8601String()}',
      tree: indexTree, // stashCommitTree
      parent: stashCommitParents,
    );
    stashCommitParents.add(stashCommitOne);
    stashCommitTree = indexTree;
    workDirCompareBase = STAGE();
  }

  final workingTree = await writeTreeChanges(
    fs: fs,
    dir: dir,
    gitdir: gitdir,
    treePair: [workDirCompareBase, 'workdir'],
  );
  if (workingTree != null) {
    // create a commit from the working directory tree, which has one parent, either the one we just had, or the headCommit
    final workingHeadCommit = await stashMgr.writeStashCommit(
      message:
          'stash-WorkDir: WIP on $branch - ${DateTime.now().toIso8601String()}',
      tree: workingTree,
      parent: [stashCommitParents.last],
    );

    stashCommitParents.add(workingHeadCommit);
    stashCommitTree = workingTree;
  }

  if (stashCommitTree == null || (indexTree == null && workingTree == null)) {
    throw NotFoundError('changes, nothing to stash');
  }

  // create another commit from the tree, which has three parents: HEAD and the commit we just made:
  final stashMsg =
      (message.trim().isNotEmpty ? message.trim() : 'WIP on $branch') +
      ': ${headCommit.substring(0, 7)} $headMsg';

  final stashCommit = await stashMgr.writeStashCommit(
    message: stashMsg,
    tree: stashCommitTree,
    parent: stashCommitParents,
  );

  // next, write this commit into .git/refs/stash:
  await stashMgr.writeStashRef(stashCommit);

  // write the stash commit to the logs
  await stashMgr.writeStashReflogEntry(
    stashCommit: stashCommit,
    message: stashMsg,
  );

  // finally, go back to a clean working directory
  await checkout(
    fs: fs,
    dir: dir,
    gitdir: gitdir,
    ref: branch,
    track: false,
    force: true, // force checkout to discard changes
  );

  return stashCommit;
}

Future<void> stashApply({
  required FileSystem fs,
  required String dir,
  required String gitdir,
  int refIdx = 0,
}) async {
  final stashMgr = GitStashManager(fs: fs, dir: dir, gitdir: gitdir);

  // get the stash commit object
  final stashCommit = await stashMgr.readStashCommit(refIdx);
  final stashParents = stashCommit.commit?.parent;

  if (stashParents == null || stashParents.isEmpty) {
    return; // no stash found
  }

  // compare the stash commit tree with its parent commit
  for (var i = 0; i < stashParents.length - 1; i++) {
    final applyingCommit = await internal_read_commit.readCommit(
      fs: fs,
      cache: {},
      gitdir: gitdir,
      oid: stashParents[i + 1],
    );
    final wasStaged = applyingCommit.commit.message.startsWith('stash-Index');

    await applyTreeChanges(
      fs: fs,
      dir: dir,
      gitdir: gitdir,
      stashCommitOid: stashParents[i + 1],
      parentCommitOid: stashParents[i],
      wasStaged: wasStaged,
    );
  }
}

Future<void> stashDrop({
  required FileSystem fs,
  required String dir,
  required String gitdir,
  int refIdx = 0,
}) async {
  final stashMgr = GitStashManager(fs: fs, dir: dir, gitdir: gitdir);
  final stashCommit = await stashMgr.readStashCommit(refIdx);
  if (stashCommit.commit == null) {
    return; // no stash found
  }
  // remove stash ref first
  final stashRefPath = stashMgr.refStashPath;
  await acquireLock(stashRefPath, () async {
    if (await fs.exists(stashRefPath)) {
      await fs.rm(stashRefPath);
    }
  });

  // read from stash reflog and list the stash commits
  var reflogEntries = await stashMgr.readStashReflogs(parsed: false);
  if (reflogEntries.isEmpty) {
    return; // no stash reflog entry
  }

  // remove the specified stash reflog entry from reflogEntries, then update the stash reflog
  reflogEntries.removeAt(refIdx);

  final stashReflogPath = stashMgr.refLogsStashPath;
  // TODO: The lock mechanism in JS used an object as a key, which is not directly translatable.
  // Consider how to properly implement locking for this section.
  // For now, proceeding without the same complex lock key.
  await acquireLock(stashReflogPath, () async {
    if (reflogEntries.isNotEmpty) {
      await fs.write(stashReflogPath, reflogEntries.join('\n'), 'utf8');
      final lastStashCommit = reflogEntries.last.split(' ')[1];
      await stashMgr.writeStashRef(lastStashCommit);
    } else {
      // remove the stash reflog file if no entry left
      if (await fs.exists(stashReflogPath)) {
        await fs.rm(stashReflogPath);
      }
    }
  });
}

Future<List<Map<String, dynamic>>> stashList({
  required FileSystem fs,
  required String dir,
  required String gitdir,
}) async {
  final stashMgr = GitStashManager(fs: fs, dir: dir, gitdir: gitdir);
  return stashMgr.readStashReflogs(parsed: true);
}

Future<void> stashClear({
  required FileSystem fs,
  required String dir,
  required String gitdir,
}) async {
  final stashMgr = GitStashManager(fs: fs, dir: dir, gitdir: gitdir);
  final stashRefPaths = [stashMgr.refStashPath, stashMgr.refLogsStashPath];

  // TODO: The lock mechanism in JS used an array as a key, which is not directly translatable.
  // Consider how to properly implement locking for this section.
  // For now, proceeding without the same complex lock key.
  await acquireLock(stashRefPaths.join(','), () async {
    // Using a concatenated string for now
    await Future.wait(
      stashRefPaths.map((path) async {
        if (await fs.exists(path)) {
          return fs.rm(path);
        }
      }),
    );
  });
}

Future<void> stashPop({
  required FileSystem fs,
  required String dir,
  required String gitdir,
  int refIdx = 0,
}) async {
  await stashApply(fs: fs, dir: dir, gitdir: gitdir, refIdx: refIdx);
  await stashDrop(fs: fs, dir: dir, gitdir: gitdir, refIdx: refIdx);
}
