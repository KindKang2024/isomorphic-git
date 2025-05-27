import 'dart:async';

import '../commands/walk.dart' as command_walk;
import '../models/file_system.dart';
import '../models/walker.dart';
import '../models/walker_entry.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

typedef WalkerMapFunction =
    Future<dynamic> Function(String filename, List<WalkerEntry?> entries);

typedef WalkerReduceFunction =
    Future<dynamic> Function(dynamic parent, List<dynamic> children);

typedef WalkerIterateCallback =
    Future<List<dynamic>> Function(List<WalkerEntry> entries);

typedef WalkerIterateFunction =
    Future<List<dynamic>> Function(
      WalkerIterateCallback walk,
      Iterable<List<WalkerEntry>> children,
    );

Future<dynamic> walk({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required List<Walker> trees,
  WalkerMapFunction? map,
  WalkerReduceFunction? reduce,
  WalkerIterateFunction? iterate,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('trees', trees);

    final fsModel = FileSystem(fs);

    return await command_walk.walk(
      fs: fsModel,
      dir: dir,
      gitdir: gitdir,
      trees: trees,
      map: map,
      reduce: reduce,
      iterate: iterate, // Dart `command_walk.walk` needs to accept this
      cache: cache,
    );
  } catch (err) {
    // err.caller = 'git.walk'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
