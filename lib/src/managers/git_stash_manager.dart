import 'dart:io';
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:async_locks/async_locks.dart';

// Assuming these are translated or will be:
import '../commands/read_commit.dart'; // _readCommit
import '../commands/write_commit.dart'; // _writeCommit
import '../errors/invalid_ref_name_error.dart';
import '../errors/missing_name_error.dart';
import '../models/git_ref_stash.dart';
import '../utils/normalize_author_object.dart';
import 'git_ref_manager.dart';
import '../models/commit.dart'; // For CommitObject, AuthorObject if defined there

// Placeholder for a global or instance-based lock for reflog writing
final _reflogLock = Lock();

class GitStashManager {
  final Directory fs; // Using Directory for fs operations
  final String dir;
  final String gitdir;
  AuthorObject? _author;

  GitStashManager({required this.fs, required this.dir, String? gitdir})
    : gitdir = gitdir ?? p.join(dir, '.git');

  static String get refStash => 'refs/stash';
  static String get refLogsStash => 'logs/refs/stash';

  String get refStashPath => p.join(gitdir, GitStashManager.refStash);
  String get refLogsStashPath => p.join(gitdir, GitStashManager.refLogsStash);

  Future<AuthorObject> getAuthor() async {
    if (_author == null) {
      _author = await normalizeAuthorObject(fs: fs, gitdir: gitdir, author: {});
      if (_author == null) throw MissingNameError('author');
    }
    return _author!;
  }

  Future<String?> getStashSHA(int refIdx, [List<String>? stashEntries]) async {
    final stashFile = File(refStashPath);
    if (!await stashFile.exists()) {
      return null;
    }

    final entries = stashEntries ?? await readStashReflogs(parsed: false);
    if (refIdx < 0 || refIdx >= entries.length) return null;
    return entries[refIdx].split(' ')[1];
  }

  Future<String> writeStashCommit({
    required String message,
    required String tree, // OID of the tree
    required List<String> parent, // List of parent OIDs
  }) async {
    final author = await getAuthor();
    final commit = CommitObject(
      message: message,
      tree: tree,
      parents: parent,
      author: author,
      committer: author,
      pgpSignature: null,
    );
    return writeCommit(fs: fs, gitdir: gitdir, commit: commit);
  }

  Future<CommitObject?> readStashCommit(int refIdx) async {
    final stashEntries = await readStashReflogs(parsed: false);
    if (refIdx != 0) {
      if (refIdx < 0 || refIdx >= stashEntries.length) {
        throw InvalidRefNameError(
          'stash@$refIdx',
          'number that is in range of [0, num of stash pushed]',
        );
      }
    }
    if (stashEntries.isEmpty && refIdx == 0) return null; // No stash found
    if (refIdx >= stashEntries.length) return null; // Index out of bounds

    final stashSHA = await getStashSHA(refIdx, stashEntries);
    if (stashSHA == null) {
      return null; // No stash found or invalid index
    }

    return readCommit(
      fs: fs,
      // cache: {}, // Cache handling might differ in Dart
      gitdir: gitdir,
      oid: stashSHA,
    );
  }

  Future<void> writeStashRef(String stashCommit) {
    return GitRefManager.writeRef(
      fs: fs,
      gitdir: gitdir,
      ref: GitStashManager.refStash,
      value: stashCommit,
    );
  }

  Future<void> writeStashReflogEntry({
    required String stashCommit,
    required String message,
  }) async {
    final author = await getAuthor();
    final entry = GitRefStash.createStashReflogEntry(
      author,
      stashCommit,
      message,
    );
    final filepath = refLogsStashPath;

    await _reflogLock.synchronized(() async {
      final file = File(filepath);
      String appendTo = '';
      if (await file.exists()) {
        appendTo = await file.readAsString();
      }
      await file.parent.create(
        recursive: true,
      ); // Ensure logs/refs directory exists
      await file.writeAsString(appendTo + entry, flush: true);
    });
  }

  // Returns List<String> if parsed is false, List<ParsedReflogEntry> if true
  Future<List<dynamic>> readStashReflogs({bool parsed = false}) async {
    final file = File(refLogsStashPath);
    if (!await file.exists()) {
      return [];
    }

    final reflogString = await file.readAsString();
    return GitRefStash.getStashReflogEntries(reflogString, parsed);
  }
}

// Define AuthorObject if not already defined (e.g. in models/commit.dart)
// class AuthorObject {
//   final String name;
//   final String email;
//   final int timestamp;
//   final int timezoneOffset;
//   AuthorObject({
//     required this.name,
//     required this.email,
//     required this.timestamp,
//     required this.timezoneOffset,
//   });
//   Map<String, dynamic> toJson() => {
//     'name': name,
//     'email': email,
//     'timestamp': timestamp,
//     'timezoneOffset': timezoneOffset,
//   };
// }
