import 'dart:async';

import '../commands/read_tree.dart' as read_tree;
import '../errors/not_found_error.dart';
import '../errors/object_type_error.dart';
import '../managers/git_ignore_manager.dart';
import '../managers/git_index_manager.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart' as read_object;
import '../utils/assert_parameter.dart';
import '../utils/compare_stats.dart';
import '../utils/hash_object.dart';
import '../utils/join.dart';

// Possible status values
// enum GitStatus {
//   ignored,
//   unmodified,
//   modifiedStaged, // *modified
//   deletedStaged, // *deleted
//   addedStaged, // *added
//   absent,
//   modified,
//   deleted,
//   added,
//   unmodifiedWorkingTree, // *unmodified
//   absentInWorkingTree, // *absent
//   undeleted, // *undeleted
//   undeletemodified, // *undeletemodified
// }

typedef FsClient = dynamic; // Placeholder for FsClient type

Future<String> status({
  required FsClient fs,
  required String dir,
  String? gitdir,
  required String filepath,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', gitdir ?? join(dir, '.git'));
    assertParameter('filepath', filepath);

    final fsModel = FileSystem(fs);
    gitdir ??= join(dir, '.git');

    final ignored = await GitIgnoreManager.isIgnored(
      fs: fsModel,
      gitdir: gitdir,
      dir: dir,
      filepath: filepath,
    );
    if (ignored) {
      return 'ignored';
    }

    final headTree = await _getHeadTree(
      fs: fsModel,
      cache: cache,
      gitdir: gitdir,
    );
    final treeOid = await _getOidAtPath(
      fs: fsModel,
      cache: cache,
      gitdir: gitdir,
      tree: headTree,
      path: filepath,
    );

    final indexEntry = await GitIndexManager.acquire(
      fs: fsModel,
      gitdir: gitdir,
      cache: cache,
      (index) {
        for (final entry in index) {
          if (entry.path == filepath) return entry;
        }
        return null;
      },
    );

    final stats = await fsModel.lstat(join(dir, filepath));

    final H = treeOid != null; // head
    final I = indexEntry != null; // index
    final W = stats != null; // working dir

    Future<String?> getWorkdirOid() async {
      if (I && !compareStats(indexEntry, stats)) {
        return indexEntry.oid;
      } else {
        final object = await fsModel.read(join(dir, filepath));
        final workdirOid = await hashObject(
          gitdir: gitdir!,
          type: 'blob',
          object: object,
        );
        // If the oid in the index === working dir oid but stats differed update cache
        if (I && indexEntry.oid == workdirOid) {
          // and as long as our fs.stats aren't bad.
          // size of -1 happens over a BrowserFS HTTP Backend that doesn't serve Content-Length headers
          // (like the Karma webserver) because BrowserFS HTTP Backend uses HTTP HEAD requests to do fs.stat
          if (stats.size != -1) {
            // We don't await this so we can return faster for one-off cases.
            GitIndexManager.acquire(fs: fsModel, gitdir: gitdir, cache: cache, (
              index,
            ) {
              index.insert(filepath: filepath, stats: stats, oid: workdirOid);
            });
          }
        }
        return workdirOid;
      }
    }

    if (!H && !W && !I) return 'absent'; // ---
    if (!H && !W && I) return '*absent'; // -A-
    if (!H && W && !I) return '*added'; // --A
    if (!H && W && I) {
      final workdirOid = await getWorkdirOid();
      return workdirOid == indexEntry.oid ? 'added' : '*added'; // -AA : -AB
    }
    if (H && !W && !I) return 'deleted'; // A--
    if (H && !W && I) {
      return treeOid == indexEntry.oid ? '*deleted' : '*deleted'; // AA- : AB-
    }
    if (H && W && !I) {
      final workdirOid = await getWorkdirOid();
      return workdirOid == treeOid
          ? '*undeleted'
          : '*undeletemodified'; // A-A : A-B
    }
    if (H && W && I) {
      final workdirOid = await getWorkdirOid();
      if (workdirOid == treeOid) {
        return workdirOid == indexEntry.oid
            ? 'unmodified'
            : '*unmodified'; // AAA : ABA
      } else {
        return workdirOid == indexEntry.oid
            ? 'modified'
            : '*modified'; // ABB : AAB
      }
    }
    // Should not be reached
    return 'absent';
  } catch (err) {
    // In Dart, it's more common to let exceptions propagate or handle them specifically.
    // For now, rethrowing. Consider specific error handling or a custom error class.
    // err.caller = 'git.status'; // This dynamic property assignment isn't typical in Dart.
    rethrow;
  }
}

Future<String?> _getOidAtPath({
  required FileSystem fs,
  required Map<String, dynamic> cache,
  required String gitdir,
  required GitTree tree,
  required String path,
}) async {
  List<String> pathParts = path.split('/');
  final dirname = pathParts.removeAt(0);
  for (final entry in tree.entries) {
    if (entry.path == dirname) {
      if (pathParts.isEmpty) {
        return entry.oid;
      }
      final objectReadResult = await read_object.readObject(
        fs: fs,
        cache: cache,
        gitdir: gitdir,
        oid: entry.oid,
      );
      if (objectReadResult.type == 'tree') {
        final subTree = GitTree.fromBytes(objectReadResult.object);
        return _getOidAtPath(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          tree: subTree,
          path: pathParts.join('/'),
        );
      }
      if (objectReadResult.type == 'blob') {
        throw ObjectTypeError(
          oid: entry.oid,
          actualType: objectReadResult.type,
          expectedType: 'blob',
          filepath: pathParts.join('/'),
        );
      }
    }
  }
  return null;
}

Future<GitTree> _getHeadTree({
  required FileSystem fs,
  required Map<String, dynamic> cache,
  required String gitdir,
}) async {
  // Get the tree from the HEAD commit.
  String? oid;
  try {
    oid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: 'HEAD');
  } catch (e) {
    // Handle fresh branches with no commits
    if (e is NotFoundError) {
      return GitTree.fromEntries([]); // Return an empty tree
    }
    rethrow;
  }
  final treeResult = await read_tree.readTree(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
  );
  return treeResult.tree;
}
