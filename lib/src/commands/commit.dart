import 'dart:async';

import '../errors/missing_name_error.dart';
import '../errors/missing_parameter_error.dart';
import '../errors/no_commit_error.dart';
import '../managers/git_index_manager.dart';
import '../managers/git_ref_manager.dart';
import '../models/git_commit.dart';
import '../models/git_tree.dart';
import '../models/file_system.dart';
import '../storage/write_object.dart';
import '../utils/flat_file_list_to_directory_structure.dart';
import '../utils/normalize_author_object.dart';
import '../utils/normalize_committer_object.dart';
import '../utils/callbacks.dart';
import '../commands/read_commit.dart';

class CommitAuthor {
  String? name;
  String? email;
  int? timestamp;
  int? timezoneOffset;

  CommitAuthor({this.name, this.email, this.timestamp, this.timezoneOffset});
}

class CommitCommitter {
  String? name;
  String? email;
  int? timestamp;
  int? timezoneOffset;

  CommitCommitter({this.name, this.email, this.timestamp, this.timezoneOffset});
}

Future<String> commit({
  required FileSystem fs,
  required dynamic cache,
  SignCallback? onSign,
  required String gitdir,
  String? message,
  CommitAuthor? authorInput,
  CommitCommitter? committerInput,
  String? signingKey,
  bool amend = false,
  bool dryRun = false,
  bool noUpdateBranch = false,
  String? ref,
  List<String>? parent,
  String? tree,
}) async {
  // Determine ref and the commit pointed to by ref, and if it is the initial commit
  bool initialCommit = false;
  if (ref == null) {
    ref = await GitRefManager.resolve(
      fs: fs,
      gitdir: gitdir,
      ref: 'HEAD',
      depth: 2,
    );
  }

  String? refOid;
  ReadCommitResult? refCommitResult;
  try {
    refOid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: ref!);
    refCommitResult = await readCommit(
      fs: fs,
      gitdir: gitdir,
      oid: refOid,
      cache: {},
    );
  } catch (_) {
    // We assume that there's no commit and this is the initial commit
    initialCommit = true;
  }

  if (amend && initialCommit) {
    throw NoCommitError(ref!);
  }

  // Determine author and committer information
  final author = !amend
      ? await normalizeAuthorObject(fs: fs, gitdir: gitdir, author: authorInput)
      : await normalizeAuthorObject(
          fs: fs,
          gitdir: gitdir,
          author: authorInput,
          commit: refCommitResult?.commit,
        );
  if (author == null) throw MissingNameError('author');

  final committer = !amend
      ? await normalizeCommitterObject(
          fs: fs,
          gitdir: gitdir,
          author: author,
          committer: committerInput,
        )
      : await normalizeCommitterObject(
          fs: fs,
          gitdir: gitdir,
          author: author,
          committer: committerInput,
          commit: refCommitResult?.commit,
        );
  if (committer == null) throw MissingNameError('committer');

  return GitIndexManager.acquire(
    fs: fs,
    gitdir: gitdir,
    cache: cache,
    allowUnmerged: false,
    callback: (index) async {
      final inodes = flatFileListToDirectoryStructure(index.entries);
      final inode = inodes.get('.')!;
      if (tree == null) {
        tree = await _constructTree(
          fs: fs,
          gitdir: gitdir,
          inode: inode,
          dryRun: dryRun,
        );
      }

      // Determine parents of this commit
      if (parent == null) {
        if (!amend) {
          parent = refOid != null ? [refOid] : [];
        } else {
          parent = refCommitResult!.commit.parent;
        }
      } else {
        // ensure that the parents are oids, not refs
        parent = await Future.wait(
          parent.map((p) {
            return GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: p);
          }).toList(),
        );
      }

      // Determine message of this commit
      if (message == null) {
        if (!amend) {
          throw MissingParameterError('message');
        } else {
          message = refCommitResult!.commit.message;
        }
      }

      // Create and write new Commit object
      var gitCommit = GitCommit.from({
        'tree': tree!,
        'parent': parent,
        'author': author.toMap(),
        'committer': committer.toMap(),
        'message': message,
      });

      if (signingKey != null && onSign != null) {
        gitCommit = await GitCommit.sign(gitCommit, onSign, signingKey);
      }

      final oid = await writeObject(
        fs: fs,
        gitdir: gitdir,
        type: 'commit',
        object: gitCommit.toObject(),
        dryRun: dryRun,
      );

      if (!noUpdateBranch && !dryRun) {
        // Update branch pointer
        await GitRefManager.writeRef(
          fs: fs,
          gitdir: gitdir,
          ref: ref!,
          value: oid,
        );
      }
      return oid;
    },
  );
}

Future<String> _constructTree({
  required FileSystem fs,
  required String gitdir,
  required Inode inode,
  required bool dryRun,
}) async {
  // use depth first traversal
  final children = inode.children;
  for (final childInode in children) {
    if (childInode.type == 'tree') {
      childInode.metadata.mode = '040000';
      childInode.metadata.oid = await _constructTree(
        fs: fs,
        gitdir: gitdir,
        inode: childInode,
        dryRun: dryRun,
      );
    }
  }
  final entries = children
      .map(
        (childInode) => GitTreeEntry(
          mode: childInode.metadata.mode!,
          path: childInode.basename,
          oid: childInode.metadata.oid!,
          type: childInode.type!,
        ),
      )
      .toList();

  final tree = GitTree.fromEntries(entries);
  final oid = await writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'tree',
    object: tree.toObject(),
    dryRun: dryRun,
  );
  return oid;
}
