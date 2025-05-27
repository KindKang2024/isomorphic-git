import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:ignore/ignore.dart';

// I'm putting this in a Manager because I reckon it could benefit
// from a LOT of caching.
class GitIgnoreManager {
  static Future<bool> isIgnored({
    required Directory
    fs, // In Dart, we typically use Directory for fs operations
    required String dir,
    String? gitdir,
    required String filepath,
  }) async {
    gitdir ??= p.join(dir, '.git');

    // ALWAYS ignore ".git" folders.
    if (p.basename(filepath) == '.git') return true;
    // '.' is not a valid gitignore entry, so '.' is never ignored
    if (filepath == '.') return false;

    // Check and load exclusion rules from project exclude file (.git/info/exclude)
    String excludes = '';
    final excludesFile = File(p.join(gitdir, 'info', 'exclude'));
    if (await excludesFile.exists()) {
      excludes = await excludesFile.readAsString();
    }

    // Find all the .gitignore files that could affect this file
    final pairs = <Map<String, String>>[];
    pairs.add({'gitignore': p.join(dir, '.gitignore'), 'filepath': filepath});

    final pieces = filepath.split('/').where((s) => s.isNotEmpty).toList();
    for (var i = 1; i < pieces.length; i++) {
      final folder = pieces.sublist(0, i).join('/');
      final file = pieces.sublist(i).join('/');
      pairs.add({
        'gitignore': p.join(dir, folder, '.gitignore'),
        'filepath': file,
      });
    }

    bool ignoredStatus = false;
    for (final pairData in pairs) {
      final gitignorePath = pairData['gitignore']!;
      final currentFilepath = pairData['filepath']!;
      String? fileContent;
      try {
        final gitignoreFile = File(gitignorePath);
        if (await gitignoreFile.exists()) {
          fileContent = await gitignoreFile.readAsString();
        }
      } catch (e) {
        // In Dart, check for FileSystemException for NOENT equivalent
        if (e is FileSystemException && e.osError?.errorCode == 2) {
          // ENOENT
          continue;
        }
        rethrow; // Rethrow other exceptions
      }

      if (fileContent == null) continue;

      final ign = Ignore();
      if (excludes.isNotEmpty) {
        ign.add(excludes.split('\n'));
      }
      ign.add(fileContent.split('\n'));

      // If the parent directory is excluded, we are done.
      final parentdir = p.dirname(currentFilepath);
      if (parentdir != '.' && ign.ignores(parentdir)) return true;

      // If the file is currently ignored, test for UNignoring.
      // The ignore package in Dart works a bit differently.
      // `ignores` checks if a path is ignored.
      // There isn't a direct equivalent of `test().unignored`.
      // We need to check if it's NOT ignored by a negated pattern.
      if (ignoredStatus) {
        // If it was ignored, check if it's still ignored by current rules.
        // This logic needs careful translation based on `ignore` package behavior
        // For now, sticking to a direct translation of the JS logic:
        // if it was ignored, it remains ignored unless a rule un-ignores it.
        // The `ignore` package doesn't have a direct `unignored` state from `test`.
        // A file is unignored if a negation pattern matches it AND no other pattern ignores it.
        // This is complex. Let's simplify: if it becomes *not* ignored by current rules, update status.
        if (!ign.ignores(currentFilepath)) {
          // This part is tricky. The original JS logic is:
          // ignoredStatus = !ign.test(p.filepath).unignored
          // This means if it *was* ignored, it stays ignored *unless* it's explicitly unignored.
          // The Dart `ignore` package `ignores()` method returns true if it matches an ignore pattern,
          // and false if it matches a negation pattern or no pattern.
          // We need to consider if a *negation* pattern matches.
          bool isNegated = ign.isIgnored(
            currentFilepath,
            true,
          ); // Check for negation
          if (isNegated) {
            ignoredStatus = false; // It's unignored
          } else {
            // It's not explicitly unignored, and wasn't covered by a more general ignore rule above.
            // So it remains ignored if it matches any positive ignore rule.
            ignoredStatus = ign.ignores(currentFilepath);
          }
        }
      } else {
        ignoredStatus = ign.ignores(currentFilepath);
      }
    }
    return ignoredStatus;
  }
}
