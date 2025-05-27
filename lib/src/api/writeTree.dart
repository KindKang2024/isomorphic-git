import 'dart:async';

import '../commands/write_tree.dart' as command_write_tree;
import '../models/file_system.dart';
import '../models/git_tree.dart'; // Assuming GitTree model for TreeObject
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

// typedef TreeObject = List<Map<String, dynamic>>; // From JS, represented by GitTree in Dart

Future<String> writeTree({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required List<GitTreeEntry>
  treeEntries, // Using List<GitTreeEntry> for tree argument
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('tree', treeEntries); // Parameter name in JS is 'tree'

    // The command_write_tree.writeTree likely expects a GitTree object,
    // not a raw list of entries if it mirrors other similar commands.
    // If it expects a List<GitTreeEntry>, this is fine. Otherwise, construct GitTree.
    // For now, assuming it can take the list directly, or it will be adapted.
    return await command_write_tree.writeTree(
      fs: FileSystem(fs),
      gitdir: gitdir,
      tree: treeEntries, // Pass the Dart object (List<GitTreeEntry>)
    );
  } catch (err) {
    // err.caller = 'git.writeTree'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
