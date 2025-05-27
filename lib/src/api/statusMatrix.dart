import 'dart:async';

import '../commands/stage.dart';
import '../commands/tree.dart';
import '../commands/workdir.dart';
import '../commands/walk.dart' as walk_command;
import '../managers/git_ignore_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/worth_walking.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type
typedef FilterFunction = bool Function(String filepath);

// type StatusRow = [Filename, HeadStatus, WorkdirStatus, StageStatus]
typedef StatusRow = List<dynamic>; // String, int, int, int

Future<List<StatusRow>> statusMatrix({
  required FsClient fs,
  required String dir,
  String? gitdir,
  String ref = 'HEAD',
  List<String> filepaths = const ['.'],
  FilterFunction? filter,
  Map<String, dynamic> cache = const {},
  bool ignored = false,
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', gitdir ?? join(dir, '.git'));
    assertParameter('ref', ref);

    final fsModel = FileSystem(fs);
    gitdir ??= join(dir, '.git');

    return await walk_command.walk(
      fs: fsModel,
      cache: cache,
      dir: dir,
      gitdir: gitdir,
      trees: [
        tree(ref: ref),
        workdir(),
        stage(),
      ],
      map: (filepath, entries) async {
        final head = entries[0];
        final work = entries[1];
        final st = entries[2];

        // Ignore ignored files, but only if they are not already tracked.
        if (head == null && st == null && work != null) {
          if (!ignored) {
            final isIgnored = await GitIgnoreManager.isIgnored(
              fs: fsModel,
              dir: dir,
              filepath: filepath,
            );
            if (isIgnored) {
              return null;
            }
          }
        }

        // match against base paths
        if (!filepaths.any((base) => worthWalking(filepath, base))) {
          return null;
        }

        // Late filter against file names
        if (filter != null) {
          if (!filter(filepath)) return null;
        }

        final headType = head != null ? await head.type() : null;
        final workdirType = work != null ? await work.type() : null;
        final stageType = st != null ? await st.type() : null;

        final isBlob = [headType, workdirType, stageType].contains('blob');

        // For now, bail on directories unless the file is also a blob in another tree
        if ((headType == 'tree' || headType == 'special') && !isBlob)
          return null;
        if (headType == 'commit') return null;

        if ((workdirType == 'tree' || workdirType == 'special') && !isBlob) {
          return null;
        }

        if (stageType == 'commit') return null;
        if ((stageType == 'tree' || stageType == 'special') && !isBlob)
          return null;

        // Figure out the oids for files, using the staged oid for the working dir oid if the stats match.
        final headOid = headType == 'blob' ? await head!.oid() : null;
        final stageOid = stageType == 'blob' ? await st!.oid() : null;
        String? workdirOid;
        if (headType != 'blob' &&
            workdirType == 'blob' &&
            stageType != 'blob') {
          // We don't actually NEED the sha. Any sha will do
          // TODO: update this logic to handle N trees instead of just 3.
          workdirOid = '42';
        } else if (workdirType == 'blob') {
          workdirOid = await work!.oid();
        }

        final entry = [null, headOid, workdirOid, stageOid];
        // Dart's List.indexOf returns -1 if not found, which is different from JS.
        // We need to replicate the JS behavior where undefined values lead to specific indexing.
        // The original JS code `entry.map(value => entry.indexOf(value))` creates an array
        // where each element is the index of its first occurrence in the `entry` array itself.
        // For example, if entry = [undefined, 'oid1', 'oid2', 'oid1'],
        // the result of map would be [0, 1, 2, 1].
        // Then `result.shift()` removes the first element.

        final List<int?> result = [];
        for (int i = 0; i < entry.length; i++) {
          // Find first occurence of entry[i] in entry
          var found = false;
          for (int j = 0; j < entry.length; j++) {
            if (entry[i] == entry[j]) {
              result.add(j);
              found = true;
              break;
            }
          }
          if (!found) {
            // This case should ideally not happen if entry[i] is always in entry.
            // However, to be safe, and to match JS undefined behavior, we might need a placeholder.
            // For now, adding a distinct value or handling null carefully.
            result.add(
              null,
            ); // Or some other indicator of not-found/undefined ananlog
          }
        }

        result.removeAt(0); // remove leading entry for `undefined`

        return [
          filepath,
          ...result.map((r) => r ?? 0),
        ]; // Replace null with 0 as per original logic context
      },
    );
  } catch (err) {
    // err.caller = 'git.statusMatrix'; // Dynamic property assignment
    rethrow;
  }
}
