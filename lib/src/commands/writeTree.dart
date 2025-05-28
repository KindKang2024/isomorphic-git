import 'dart:async';

import 'package:./models/git_tree.dart';
import 'package:./storage/write_object.dart';

// Assuming FileSystem and TreeObject are defined elsewhere.
// For now, using `dynamic` and a List of dynamics as placeholders.
// import '../models/file_system.dart';
// import '../models/tree_object.dart'; // Or a more specific type if available

Future<String> writeTree({
  required dynamic fs, // FileSystem fs,
  required String gitdir,
  required List<dynamic>
  tree, // TreeObject tree (often represented as an array of entries)
}) async {
  // Convert object to buffer
  // Assuming GitTree.from can handle List<dynamic> or the specific TreeObject structure
  final object = GitTree.from(tree).toObject();
  final oid = await writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'tree',
    object: object,
    format: 'content',
  );
  return oid;
}
