import 'dart:async';

import '../models/git_commit.dart';
import '../storage/write_object.dart';

// Assuming FileSystem and CommitObject are defined elsewhere.
// For now, using `dynamic` and `Map<String, dynamic>` as placeholders.
// import '../models/file_system.dart';
// import '../models/commit_object.dart'; // Or a more specific type if available

Future<String> writeCommit({
  required dynamic fs, // FileSystem fs,
  required String gitdir,
  required Map<String, dynamic> commit, // CommitObject commit,
}) async {
  // Convert object to buffer
  final object = GitCommit.from(commit).toObject();
  final oid = await writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'commit',
    object: object,
    format: 'content',
  );
  return oid;
}
