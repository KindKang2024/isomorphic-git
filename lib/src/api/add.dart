import 'dart:async';

// import '../typedefs.dart'; // Dart handles types

import '../errors/multiple_git_error.dart';
import '../errors/not_found_error.dart';
import '../managers/git_config_manager.dart';
import '../managers/git_ignore_manager.dart';
import '../managers/git_index_manager.dart';
import '../models/file_system.dart'; // Assumes FsClient and Stats are here or imported by it
import '../storage/write_object.dart'
    show writeObject; // Assuming _writeObject is exported as writeObject
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/posixify_path_buffer.dart'; // Assuming this utility exists and is similar

// Placeholder for Stats if not defined in FileSystem or elsewhere
// class Stats {
//   bool isDirectory() => false;
//   bool isSymbolicLink() => false;
//   // Add other necessary properties/methods if any
// }

/// Add a file or multiple files to the git index (aka staging area)
Future<void> add({
  required dynamic fs, // Should be FsClient
  required String dir,
  String? gitdir,
  required dynamic filepath, // String or List<String>
  Map<String, dynamic>? cache,
  bool force = false,
  bool parallel =
      true, // Note: Dart's async operations are inherently parallel-friendly without explicit flags in many cases
}) async {
  final effectiveGitdir = gitdir ?? join(dir, '.git');
  final effectiveCache = cache ?? {};

  try {
    assertParameter('fs', fs);
    assertParameter('dir', dir);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('filepath', filepath);

    final fileSystem = FileSystem(fs);
    await GitIndexManager.acquire(
      fs: fileSystem,
      gitdir: effectiveGitdir,
      cache: effectiveCache,
      callback: (index) async {
        final config = await GitConfigManager.get(
          fs: fileSystem,
          gitdir: effectiveGitdir,
        );
        // TODO: core.autocrlf might need specific handling if it returns non-boolean in Dart.
        final autocrlf = await config.get('core.autocrlf');

        await _addToIndex(
          dir: dir,
          gitdir: effectiveGitdir,
          fs: fileSystem,
          filepath: filepath is String
              ? [filepath]
              : List<String>.from(filepath),
          index: index,
          force: force,
          parallel:
              parallel, // Consider if this flag is still needed or how it translates to Dart's concurrency
          autocrlf: autocrlf, // Pass autocrlf setting
        );
      },
    );
  } catch (err) {
    // Consider custom error handling or re-propagating specific error types
    // err.caller = 'git.add'; // This pattern is JS specific
    print("Error in git.add: $err");
    rethrow;
  }
}

Future<List<dynamic>> _addToIndex({
  required String dir,
  required String gitdir,
  required FileSystem fs,
  required List<String> filepaths,
  required dynamic index, // Assuming GitIndexManager instance or similar
  required bool force,
  required bool parallel,
  required dynamic autocrlf, // Type depends on what config.get returns
}) async {
  List<Future<void>> futures = [];

  for (String currentFilepath in filepaths) {
    Future<void> processFile() async {
      if (!force) {
        final ignored = await GitIgnoreManager.isIgnored(
          fs: fs,
          dir: dir,
          gitdir: gitdir,
          filepath: currentFilepath,
        );
        if (ignored) return; // Skip if ignored and not forcing
      }

      String fullPath = join(dir, currentFilepath);
      // TODO: Ensure fs.lstat exists and returns a compatible Stats object
      final dynamic stats = await fs.lstat(fullPath);
      if (stats == null) throw NotFoundError(currentFilepath);

      if (stats.isDirectory()) {
        // TODO: Ensure fs.readdir exists
        final List<String> children = await fs.readdir(fullPath);
        List<String> childPaths = children
            .map((child) => join(currentFilepath, child))
            .toList();

        if (parallel) {
          // Dart's Future.wait achieves parallelism for async operations
          await _addToIndex(
            dir: dir,
            gitdir: gitdir,
            fs: fs,
            filepaths: childPaths,
            index: index,
            force: force,
            parallel: parallel, // Recursive call maintains parallel strategy
            autocrlf: autocrlf,
          );
        } else {
          // Sequential processing for directories if parallel is false
          for (String childPath in childPaths) {
            await _addToIndex(
              dir: dir,
              gitdir: gitdir,
              fs: fs,
              filepaths: [childPath], // Process one by one
              index: index,
              force: force,
              parallel:
                  parallel, // false if we want to be strictly sequential here
              autocrlf: autocrlf,
            );
          }
        }
      } else {
        // TODO: Ensure fs.readlink and fs.read are implemented and handle autocrlf
        dynamic object;
        if (stats.isSymbolicLink()) {
          String linkPath = await fs.readlink(fullPath);
          // Ensure posixifyPathBuffer equivalent exists and handles the type from readlink
          object = posixifyPathBuffer(
            linkPath,
          ); // Assuming linkPath is String or Buffer-like
        } else {
          // fs.read should ideally handle autocrlf based on the passed boolean/value
          object = await fs.read(fullPath, autocrlf: autocrlf);
        }

        if (object == null) throw NotFoundError(currentFilepath);

        // TODO: Ensure _writeObject (or its Dart equivalent `writeObject`) is correctly imported and used
        final String oid = await writeObject(
          fs: fs,
          gitdir: gitdir,
          type: 'blob',
          object: object,
        );

        // TODO: Ensure index.insert is compatible with the Stats object and OID
        index.insert(filepath: currentFilepath, stats: stats, oid: oid);
      }
    }

    futures.add(processFile());
  }

  // Handle results of all parallel operations
  final List<dynamic> results = await Future.wait(
    futures.map((f) => f.then((value) => null).catchError((e) => e)),
    eagerError: false,
  );

  List<dynamic> rejectedReasons = results.where((r) => r != null).toList();

  if (rejectedReasons.length > 1) {
    throw MultipleGitError(
      rejectedReasons,
    ); // Assuming MultipleGitError can take a list of errors
  }
  if (rejectedReasons.length == 1) {
    throw rejectedReasons[0];
  }

  // The original JS returned fulfilledPromises, but add returns void.
  // If specific return values from each successful add are needed, this part needs adjustment.
  // For now, mimicking void return on success, throwing on error.
  return []; // Or simply don't return anything if function is void
}
