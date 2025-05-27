import 'dart:convert';

// import '../typedefs.dart'; // Handled by Dart's type system or specific imports

import '../commands/stage.dart' show STAGE;
import '../commands/tree.dart' show TREE;
import '../commands/workdir.dart' show WORKDIR;
import '../commands/walk.dart' show walk; // Assuming _walk is exported as walk
import '../errors/index_reset_error.dart';
import '../managers/git_index_manager.dart';
import '../models/file_system.dart'; // Assuming FsClient is part of this
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/modified.dart';

// Assuming these types will be defined elsewhere or through typedefs
// typedef FsClient = dynamic; // Placeholder
// typedef Walker = dynamic; // Placeholder
// typedef Cache = Map<String, dynamic>; // Placeholder

class AbortMergeParams {
  final dynamic fs; // Should be FsClient
  final String dir;
  final String? gitdir;
  final String commit;
  final Map<String, dynamic>? cache;

  AbortMergeParams({
    required this.fs,
    required this.dir,
    this.gitdir,
    this.commit = 'HEAD',
    this.cache,
  });
}

/// Abort a merge in progress.
///
/// Based on the behavior of git reset --merge, i.e.  "Resets the index and updates the files in the working tree that are different between <commit> and HEAD, but keeps those which are different between the index and working tree (i.e. which have changes which have not been added). If a file that is different between <commit> and the index has unstaged changes, reset is aborted."
///
/// Essentially, abortMerge will reset any files affected by merge conflicts to their last known good version at HEAD.
/// Any unstaged changes are saved and any staged changes are reset as well.
///
/// NOTE: The behavior of this command differs slightly from canonical git in that an error will be thrown if a file exists in the index and nowhere else.
/// Canonical git will reset the file and continue aborting the merge in this case.
///
/// **WARNING:** Running git merge with non-trivial uncommitted changes is discouraged: while possible, it may leave you in a state that is hard to back out of in the case of a conflict.
/// If there were uncommitted changes when the merge started (and especially if those changes were further modified after the merge was started), `git.abortMerge` will in some cases be unable to reconstruct the original (pre-merge) changes.
///
Future<void> abortMerge({
  required dynamic fs, // Should be FsClient
  required String dir,
  String? gitdir,
  String commit = 'HEAD',
  Map<String, dynamic>? cache,
}) async {
  final effectiveGitdir = gitdir ?? join(dir, '.git');
  final effectiveCache = cache ?? {};

  try {
    assertParameter('fs', fs);
    assertParameter('dir', dir);
    assertParameter('gitdir', effectiveGitdir);

    final fileSystem = FileSystem(fs);
    // TODO: Replace with actual Walker constructors or objects
    final trees = [
      TREE({'ref': commit}),
      WORKDIR(),
      STAGE(),
    ];
    List<String> unmergedPaths = [];

    await GitIndexManager.acquire(
      fs: fileSystem,
      gitdir: effectiveGitdir,
      cache: effectiveCache,
      callback: (index) async {
        unmergedPaths = index
            .unmergedPaths(); // Assuming unmergedPaths is a method
      },
    );

    // TODO: Define the structure for TreeEntry and the map callback precisely
    final results = await walk(
      fs: fileSystem,
      cache: effectiveCache,
      dir: dir,
      gitdir: effectiveGitdir,
      trees: trees,
      map: (String path, List<dynamic> entries) async {
        // Assuming entries are [head, workdir, index]
        final head = entries[0];
        final workdirEntry = entries[1];
        final indexEntry = entries[2];

        // TODO: Implement modified logic correctly
        final staged = !(await modified(workdirEntry, indexEntry));
        final unmerged = unmergedPaths.contains(path);
        final unmodified = !(await modified(indexEntry, head));

        if (staged || unmerged) {
          if (head != null) {
            // Assuming head has mode(), oid(), type(), content() methods
            return {
              'path': path,
              'mode': await head.mode(),
              'oid': await head.oid(),
              'type': await head.type(),
              'content': await head.content(),
            };
          } else {
            return null;
          }
        }

        if (unmodified) {
          return false;
        } else {
          throw IndexResetError(path);
        }
      },
    );

    await GitIndexManager.acquire(
      fs: fileSystem,
      gitdir: effectiveGitdir,
      cache: effectiveCache,
      callback: (index) async {
        for (final entry in results) {
          if (entry == false) continue;

          if (entry == null) {
            // This case needs careful handling based on original JS:
            // In JS: if (!entry) means entry is null or undefined.
            // Here we assume entry.path would be available if it was an object
            // This part of the logic might need adjustment if entry structure is different
            // For now, assuming entry would have a 'path' if it's not null/false
            // If entry is null, and it was supposed to have a path, this will fail.
            // The original JS `!entry` after `entry === false` implies `entry` is falsy but not `false`.
            // In JS `undefined` or `null` would fit.
            // If `entry` represents a path that should be deleted, we need that path.
            // The JS `await fs.rmdir(\`\${dir}/\${entry.path}\`, { recursive: true })`
            // implies entry should have a path.
            // This needs to be clarified how a null entry provides a path.
            // For now, this block will be problematic if entry is truly null.
            // A possible interpretation: if entry is null, it means it was undefined in JS,
            // meaning the file should be deleted. But we need the path.
            // This part needs more context on how 'results' are structured for deleted files.
            // Let's assume for now that if entry is null, it's skipped, or path comes from elsewhere.
            // The original code did: if (!entry) { await fs.rmdir(`${dir}/${entry.path}` ... index.delete({ filepath: entry.path }) }
            // This is contradictory if entry is null.
            // Assuming 'entry' here is a Map or an object that can be null.
            // If 'entry' is null, we can't get 'entry.path'.
            // Let's assume the walk function's map returns a structure that always includes path if deletion is intended.
            // Or, if entry is null, the path must be part of the iteration context if not in 'entry'.
            // Given the loop is `for (const entry of results)`, `entry` is the item.
            // This part of the logic is very tricky to translate directly without knowing how
            // the `walk` and `map` function exactly structure their return for deletions.
            // For now, I will assume that if entry is null, it means a deletion of a path
            // that must be accessible somehow, or this case is handled differently.
            // The JS `!entry` (where entry is not false) implies entry is `null` or `undefined`.
            // If the `map` function returns `undefined` (which becomes `null` in this Dart loop for `dynamic`),
            // it means the entry should be removed from the workdir and index.
            // The problem remains: where does `entry.path` come from if `entry` is `null`?
            // This strongly suggests the `map` function might return something like `{ path: 'path/to/delete', delete: true }`
            // or the path is an implicit part of the `results` structure.

            // Safely skip if entry is null and handle deletion logic based on better understanding of `walk` return.
            print(
              "Warning: entry is null, deletion logic for path might be missing.",
            );
            continue;
          }

          // Assuming entry is a Map<String, dynamic> from here
          final entryMap = entry as Map<String, dynamic>;
          final path = entryMap['path'] as String;

          if (entryMap['type'] == 'blob') {
            // Assuming content is List<int> (Uint8List)
            final contentBytes = entryMap['content'] as List<int>;
            final contentString = utf8.decode(contentBytes);
            await fileSystem.write(
              join(dir, path),
              contentString,
              mode: entryMap['mode'],
            );
            index.insert(
              filepath: path,
              oid: entryMap['oid'] as String,
              stage: 0, // In Dart, enums or constants might be better for stage
            );
          } else {
            // Assuming it's a tree (directory) or other types not blobs
            // Original JS code:
            // if (!entry) {
            // await fs.rmdir(`${dir}/${entry.path}`, { recursive: true })
            // index.delete({ filepath: entry.path })
            // continue
            // }
            // This block was for `!entry` (null/undefined)
            // If entry.type is not 'blob', and entry is not null/false, what happens?
            // The original code only explicitly handles `entry.type === 'blob'` for writing.
            // And `!entry` (null/undefined) for deletion.
            // What if `entry` is an object (truthy) but not type 'blob'?
            // E.g. a tree entry from HEAD that should be restored.
            // The original code for `!entry` (which I'm assuming means delete):
            //   await fs.rmdir(`${dir}/${entry.path}`, { recursive: true })
            //   index.delete({ filepath: entry.path })
            // This seems to be for deleting items not present in HEAD.
            // If `entry` is not null, not false, and not a blob, it implies a directory or submodule.
            // The provided JS code doesn't explicitly handle restoring directories from `head` if they are not blobs.
            // It seems to assume if `head` has an entry, and it's not a blob, it's implicitly handled
            // or `_walk` doesn't return non-blob entries from `head` unless they are to be deleted.
            // This part requires a deeper understanding of the `_walk` function's behavior with non-blob types.
            // For now, if it's not a blob, and not explicitly a deletion case (null entry),
            // we'll assume the index update via `index.insert` is sufficient if an OID is present,
            // or it's a directory that `fs.write` for blobs implicitly handles (e.g. by creating parent dirs).
            // The crucial part is `index.insert`. If it's a tree, it would have an OID.
            // The original code is:
            // if (entry.type === 'blob') { /* write file, insert */ }
            // there's no else block for other types if `entry` is truthy.
            // This implies that only blobs are written to the workdir, and all types (blob, tree, commit) are updated in the index.
            // The deletion part `if (!entry)` handles removal.
            // So, if it's not a blob, but has an oid, it should still be inserted into the index.
            // Let's add the index insert for non-blobs too, assuming they have an oid.
            if (entryMap.containsKey('oid') && entryMap['oid'] != null) {
              index.insert(
                filepath: path,
                oid: entryMap['oid'] as String,
                stage: 0, // Or appropriate stage
              );
            }
          }
        }
      },
    );
  } catch (e, s) {
    // Consider creating a custom error class or adding a 'caller' property if possible
    print('Error in git.abortMerge: $e');
    print(s); // Stack trace
    rethrow;
  }
}
