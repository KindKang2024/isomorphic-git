import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:async_locks/async_locks.dart';

final _lock = Lock();

class GitShallowManager {
  static Future<Set<String>> read({
    required Directory fs, // Using Directory for fs operations
    required String gitdir,
  }) async {
    final filepath = p.join(gitdir, 'shallow');
    final oids = <String>{};

    await _lock.synchronized(() async {
      final file = File(filepath);
      if (!await file.exists()) {
        return; // no file
      }
      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        return; // empty file
      }
      text.trim().split('\n').forEach((oid) => oids.add(oid));
    });
    return oids;
  }

  static Future<void> write({
    required Directory fs, // Using Directory for fs operations
    required String gitdir,
    required Set<String> oids,
  }) async {
    final filepath = p.join(gitdir, 'shallow');

    await _lock.synchronized(() async {
      final file = File(filepath);
      if (oids.isNotEmpty) {
        final text = oids.join('\n') + '\n';
        await file.writeAsString(text);
      } else {
        // No shallows
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  }
}
