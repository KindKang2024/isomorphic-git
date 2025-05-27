import 'dart:io';

import '../commands/read_commit.dart';
import '../errors/not_found_error.dart';
import '../managers/git_ref_manager.dart';
import '../managers/git_shallow_manager.dart';
import '../models/read_commit_result.dart';
import '../utils/compare_age.dart';
import '../utils/resolve_file_id_in_tree.dart';
import '../utils/resolve_filepath.dart';

Future<List<ReadCommitResult>> log({
  required Directory fs,
  required dynamic cache,
  required String gitdir,
  String? filepath,
  required String ref,
  int? depth,
  DateTime? since,
  bool force = false,
  bool follow = false,
}) async {
  final sinceTimestamp = since == null
      ? null
      : (since.millisecondsSinceEpoch ~/ 1000);

  final commits = <ReadCommitResult>[];
  final shallowCommits = await GitShallowManager.read(fs: fs, gitdir: gitdir);
  final oid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: ref);
  final tips = [
    await readCommit(fs: fs, cache: cache, gitdir: gitdir, oid: oid),
  ];

  String? lastFileOid;
  ReadCommitResult? lastCommit;
  var isOk = false;

  void endCommit(ReadCommitResult commit) {
    if (isOk && filepath != null) commits.add(commit);
  }

  while (tips.isNotEmpty) {
    final commit = tips.removeLast();

    if (sinceTimestamp != null &&
        commit.commit.committer.timestamp <= sinceTimestamp) {
      break;
    }

    if (filepath != null) {
      String? vFileOid;
      try {
        vFileOid = await resolveFilepath(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          oid: commit.commit.tree,
          filepath: filepath,
        );
        if (lastCommit != null && lastFileOid != vFileOid) {
          commits.add(lastCommit);
        }
        lastFileOid = vFileOid;
        lastCommit = commit;
        isOk = true;
      } catch (e) {
        if (e is NotFoundError) {
          String? foundFilepath;
          if (follow && lastFileOid != null) {
            final foundResult = await resolveFileIdInTree(
              fs: fs,
              cache: cache,
              gitdir: gitdir,
              oid: commit.commit.tree,
              fileId: lastFileOid!,
            );
            if (foundResult != null) {
              if (foundResult is List<String>) {
                if (lastCommit != null) {
                  final lastFound = await resolveFileIdInTree(
                    fs: fs,
                    cache: cache,
                    gitdir: gitdir,
                    oid: lastCommit.commit.tree,
                    fileId: lastFileOid!,
                  );
                  if (lastFound is List<String>) {
                    final filteredFound = foundResult
                        .where((p) => !lastFound.contains(p))
                        .toList();
                    if (filteredFound.length == 1) {
                      foundFilepath = filteredFound[0];
                      filepath = foundFilepath;
                      if (lastCommit != null) commits.add(lastCommit);
                    } else {
                      if (lastCommit != null) commits.add(lastCommit);
                      break;
                    }
                  }
                }
              } else {
                foundFilepath = foundResult as String?;
                filepath = foundFilepath!;
                if (lastCommit != null) commits.add(lastCommit);
              }
            }
          }
          if (foundFilepath == null) {
            if (isOk && lastFileOid != null) {
              commits.add(lastCommit!);
              if (!force) break;
            }
            if (!force && !follow) throw e;
          }
          lastCommit = commit;
          isOk = false;
        } else {
          rethrow;
        }
      }
    } else {
      commits.add(commit);
    }

    if (depth != null && commits.length == depth) {
      endCommit(commit);
      break;
    }

    if (!shallowCommits.contains(commit.oid)) {
      for (final parentOid in commit.commit.parents) {
        final parentCommit = await readCommit(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          oid: parentOid,
        );
        if (!tips.map((c) => c.oid).contains(parentCommit.oid)) {
          tips.add(parentCommit);
        }
      }
    }

    if (tips.isEmpty) {
      endCommit(commit);
    }
    tips.sort((a, b) => compareAge(a.commit, b.commit).toInt());
  }
  return commits;
}
