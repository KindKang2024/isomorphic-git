import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_locks/async_locks.dart';
import 'package:isomorphic_git/src/models/file_system.dart';
import 'package:path/path.dart' as p;

import '../errors/invalid_oid_error.dart';
import '../errors/no_refspec_error.dart';
import '../errors/not_found_error.dart';
import '../models/git_packed_refs.dart';
import '../models/git_refspec_set.dart';
// Assuming compareRefNames is in utils or a similar location
import '../utils/compare_ref_names.dart';
import '../models/file_system.dart';
import 'git_config_manager.dart';

// @see https://git-scm.com/docs/git-rev-parse.html#_specifying_revisions
List<String> _refpaths(String ref) => [
  ref,
  'refs/$ref',
  'refs/tags/$ref',
  'refs/heads/$ref',
  'refs/remotes/$ref',
  'refs/remotes/$ref/HEAD',
];

// @see https://git-scm.com/docs/gitrepository-layout
const _gitFiles = ['config', 'description', 'index', 'shallow', 'commondir'];

final _lock = Lock();

Future<T> _acquireLock<T>(String ref, Future<T> Function() callback) async {
  return _lock.synchronized<T>(callback, id: ref);
}

class GitRefManager {
  static Future<Map<String, List<String>>> updateRemoteRefs({
    required Directory fs, // Using Directory for fs operations
    required String gitdir,
    required String remote,
    required Map<String, String> refs,
    required Map<String, String> symrefs,
    required bool tags, // Corresponds to fetch tags behavior in JS
    List<String>? refspecs,
    bool prune = false,
    bool pruneTags = false,
  }) async {
    // Validate input
    for (final value in refs.values) {
      if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
        throw InvalidOidError(value);
      }
    }

    final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
    refspecs ??= await config.getAll('remote.$remote.fetch');

    if (refspecs.isEmpty) {
      throw NoRefspecError(remote);
    }
    // There's some interesting behavior with HEAD that doesn't follow the refspec.
    refspecs.insert(0, '+HEAD:refs/remotes/$remote/HEAD');

    final refspecSet = GitRefSpecSet.from(refspecs);
    final actualRefsToWrite = <String, String>{};

    // Delete all current tags if the pruneTags argument is true.
    if (pruneTags) {
      final currentTags = await GitRefManager.listRefs(
        fs: fs,
        gitdir: gitdir,
        filepath: 'refs/tags',
      );
      await GitRefManager.deleteRefs(
        fs: fs,
        gitdir: gitdir,
        refs: currentTags.map((tag) => 'refs/tags/$tag').toList(),
      );
    }

    // Add all tags if the fetch tags argument is true.
    if (tags) {
      for (final serverRef in refs.keys) {
        if (serverRef.startsWith('refs/tags') && !serverRef.endsWith('^{}')) {
          if (!(await GitRefManager.exists(
            fs: fs,
            gitdir: gitdir,
            ref: serverRef,
          ))) {
            final oid = refs[serverRef]!;
            actualRefsToWrite[serverRef] = oid;
          }
        }
      }
    }

    // Combine refs and symrefs giving symrefs priority
    final refTranslations = refspecSet.translate(refs.keys.toList());
    for (final entry in refTranslations.entries) {
      final serverRef = entry.key;
      final translatedRef = entry.value;
      final value = refs[serverRef]!;
      actualRefsToWrite[translatedRef] = value;
    }

    final symrefTranslations = refspecSet.translate(symrefs.keys.toList());
    for (final entry in symrefTranslations.entries) {
      final serverRef = entry.key;
      final translatedRef = entry.value;
      final value = symrefs[serverRef]!;
      final symtarget = refspecSet.translateOne(value);
      if (symtarget != null) {
        actualRefsToWrite[translatedRef] = 'ref: $symtarget';
      }
    }

    final prunedRefs = <String>[];
    if (prune) {
      for (final filepath in refspecSet.localNamespaces()) {
        final existingRefs = (await GitRefManager.listRefs(
          fs: fs,
          gitdir: gitdir,
          filepath: filepath,
        )).map((file) => '$filepath/$file').toList();
        for (final ref in existingRefs) {
          if (!actualRefsToWrite.containsKey(ref)) {
            prunedRefs.add(ref);
          }
        }
      }
      if (prunedRefs.isNotEmpty) {
        await GitRefManager.deleteRefs(
          fs: fs,
          gitdir: gitdir,
          refs: prunedRefs,
        );
      }
    }

    for (final entry in actualRefsToWrite.entries) {
      final key = entry.key;
      final value = entry.value;
      await _acquireLock(key, () async {
        final file = File(p.join(gitdir, key));
        await file.parent.create(recursive: true); // Ensure directory exists
        await file.writeAsString('${value.trim()}\n');
      });
    }
    return {'pruned': prunedRefs};
  }

  static Future<void> writeRef({
    required Directory fs,
    required String gitdir,
    required String ref,
    required String value,
  }) async {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
      throw InvalidOidError(value);
    }
    await _acquireLock(ref, () async {
      final file = File(p.join(gitdir, ref));
      await file.parent.create(recursive: true);
      await file.writeAsString('${value.trim()}\n');
    });
  }

  static Future<void> writeSymbolicRef({
    required Directory fs,
    required String gitdir,
    required String ref,
    required String value,
  }) async {
    await _acquireLock(ref, () async {
      final file = File(p.join(gitdir, ref));
      await file.parent.create(recursive: true);
      await file.writeAsString('ref: ${value.trim()}\n');
    });
  }

  static Future<void> deleteRef({
    required Directory fs,
    required String gitdir,
    required String ref,
  }) async {
    return GitRefManager.deleteRefs(fs: fs, gitdir: gitdir, refs: [ref]);
  }

  static Future<void> deleteRefs({
    required Directory fs,
    required String gitdir,
    required List<String> refs,
  }) async {
    await Future.wait(
      refs.map((ref) async {
        final file = File(p.join(gitdir, ref));
        if (await file.exists()) {
          await file.delete();
        }
      }),
    );

    final packedRefsFile = File(p.join(gitdir, 'packed-refs'));
    if (!await packedRefsFile.exists()) return;

    String text = await _acquireLock('packed-refs', () async {
      return packedRefsFile.readAsString();
    });

    final packed = GitPackedRefs.from(text);
    final beforeSize = packed.refs.length;
    for (final ref in refs) {
      packed.delete(ref);
    }

    if (packed.refs.length < beforeSize) {
      text = packed.toString();
      await _acquireLock('packed-refs', () async {
        await packedRefsFile.writeAsString(text);
      });
    }
  }

  static Future<String> resolve({
    required FileSystem fs,
    required String gitdir,
    required String ref,
    int? depth,
  }) async {
    if (depth != null) {
      depth--;
      if (depth == -1) {
        return ref;
      }
    }

    if (ref.startsWith('ref: ')) {
      ref = ref.substring('ref: '.length);
      return GitRefManager.resolve(
        fs: fs,
        gitdir: gitdir,
        ref: ref,
        depth: depth,
      );
    }

    if (ref.length == 40 && RegExp(r'^[0-9a-f]{40}$').hasMatch(ref)) {
      return ref;
    }

    final packedMap = await GitRefManager.packedRefs(fs: fs, gitdir: gitdir);
    final allpaths = _refpaths(
      ref,
    ).where((p) => !_gitFiles.contains(p)).toList();

    for (final currentRefPath in allpaths) {
      String? sha;
      final file = File(p.join(gitdir, currentRefPath));
      if (await file.exists()) {
        sha = await _acquireLock(
          currentRefPath,
          () async => file.readAsString(),
        );
      }
      sha ??= packedMap[currentRefPath];

      if (sha != null && sha.isNotEmpty) {
        return GitRefManager.resolve(
          fs: fs,
          gitdir: gitdir,
          ref: sha.trim(),
          depth: depth,
        );
      }
    }
    throw NotFoundError(ref);
  }

  static Future<bool> exists({
    required Directory fs,
    required String gitdir,
    required String ref,
  }) async {
    try {
      await GitRefManager.expand(fs: fs, gitdir: gitdir, ref: ref);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> expand({
    required Directory fs,
    required String gitdir,
    required String ref,
  }) async {
    if (ref.length == 40 && RegExp(r'^[0-9a-f]{40}$').hasMatch(ref)) {
      return ref;
    }
    final packedMap = await GitRefManager.packedRefs(fs: fs, gitdir: gitdir);
    final allpaths = _refpaths(
      ref,
    ).where((p) => !_gitFiles.contains(p)).toList();

    for (final currentRefPath in allpaths) {
      String? sha;
      final file = File(p.join(gitdir, currentRefPath));
      if (await file.exists()) {
        sha = await _acquireLock(
          currentRefPath,
          () async => file.readAsString(),
        );
      }
      sha ??= packedMap[currentRefPath];

      if (sha != null && sha.isNotEmpty) {
        if (sha.startsWith('ref: ')) {
          return GitRefManager.expand(
            fs: fs,
            gitdir: gitdir,
            ref: sha.substring('ref: '.length).trim(),
          );
        }
        return currentRefPath;
      }
    }
    throw NotFoundError(ref);
  }

  static Future<String> expandAgainstMap({
    required String ref,
    required Map<String, String> map,
  }) async {
    if (ref.length == 40 && RegExp(r'^[0-9a-f]{40}$').hasMatch(ref)) {
      return ref;
    }
    final allpaths = _refpaths(
      ref,
    ).where((p) => !_gitFiles.contains(p)).toList();
    for (final currentRefPath in allpaths) {
      final sha = map[currentRefPath];
      if (sha != null && sha.isNotEmpty) {
        if (sha.startsWith('ref: ')) {
          return expandAgainstMap(
            ref: sha.substring('ref: '.length).trim(),
            map: map,
          );
        }
        return currentRefPath;
      }
    }
    throw NotFoundError(ref);
  }

  static String resolveAgainstMap({
    required String ref,
    String? fullref, // Keeps original ref for error message
    int? depth,
    required Map<String, String> map,
  }) {
    fullref ??= ref;
    if (depth != null) {
      depth--;
      if (depth == -1) {
        // Prevent infinite loops
        throw NotFoundError(fullref);
      }
    }

    if (ref.startsWith('ref: ')) {
      ref = ref.substring('ref: '.length);
      return resolveAgainstMap(
        ref: ref,
        fullref: fullref,
        depth: depth,
        map: map,
      );
    }

    if (ref.length == 40 && RegExp(r'^[0-9a-f]{40}$').hasMatch(ref)) {
      return ref;
    }

    final allpaths = _refpaths(
      ref,
    ).where((p) => !_gitFiles.contains(p)).toList();
    for (final currentRefPath in allpaths) {
      final sha = map[currentRefPath];
      if (sha != null && sha.isNotEmpty) {
        return resolveAgainstMap(
          ref: sha.trim(),
          fullref: fullref,
          depth: depth,
          map: map,
        );
      }
    }
    throw NotFoundError(fullref);
  }

  static Future<Map<String, String>> packedRefs({
    required Directory fs,
    required String gitdir,
  }) async {
    final packedRefsFile = File(p.join(gitdir, 'packed-refs'));
    if (!await packedRefsFile.exists()) return {};

    final text = await _acquireLock('packed-refs', () async {
      return packedRefsFile.readAsString();
    });
    return GitPackedRefs.from(text).refs;
  }

  static Future<List<String>> listRefs({
    required Directory fs,
    required String gitdir,
    required String filepath,
  }) async {
    final currentPath = p.join(gitdir, filepath);
    final dir = Directory(currentPath);
    var files = <String>[];

    if (await dir.exists()) {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final name = p.relative(entity.path, from: currentPath);
          // Filter out .lock files if any exist
          if (!name.endsWith('.lock')) {
            files.add(name);
          }
        }
      }
    }

    // Also check packed-refs
    final packed = await packedRefs(fs: fs, gitdir: gitdir);
    for (final ref in packed.keys) {
      if (ref.startsWith(filepath + '/')) {
        final name = ref.substring(filepath.length + 1);
        // only add if not already found as a loose ref
        if (!files.contains(name)) {
          // And if it's not shadowed by a loose ref that's a directory
          bool shadowedByDir = false;
          for (final looseFile in files) {
            if (name.startsWith(looseFile + '/')) {
              shadowedByDir = true;
              break;
            }
          }
          if (!shadowedByDir) {
            files.add(name);
          }
        }
      }
    }
    files.sort(compareRefNames);
    return files;
  }

  static Future<List<String>> listBranches({
    required Directory fs,
    required String gitdir,
    String? remote,
  }) async {
    if (remote == null) {
      return listRefs(fs: fs, gitdir: gitdir, filepath: 'refs/heads');
    } else {
      return listRefs(fs: fs, gitdir: gitdir, filepath: 'refs/remotes/$remote');
    }
  }

  static Future<List<String>> listTags({
    required Directory fs,
    required String gitdir,
  }) async {
    final files = await listRefs(fs: fs, gitdir: gitdir, filepath: 'refs/tags');
    // Deduplicate tags between loose and packed refs, prioritizing loose.
    // The listRefs should already handle some of this by not adding packed if loose exists.
    // However, ensure no ^{} peeled tags are included if the base tag exists.
    final result = <String>[];
    final Set<String> seenTags = {};

    for (var tag in files) {
      if (tag.endsWith('^{}')) {
        var baseTag = tag.substring(0, tag.length - 3);
        if (files.contains(baseTag)) {
          // Prioritize the base tag if both exist
          if (!seenTags.contains(baseTag)) {
            result.add(baseTag);
            seenTags.add(baseTag);
          }
        } else {
          // Peeled tag exists without base tag (should be rare)
          if (!seenTags.contains(tag)) {
            result.add(tag);
            seenTags.add(tag);
          }
        }
      } else {
        if (!seenTags.contains(tag)) {
          result.add(tag);
          seenTags.add(tag);
        }
      }
    }
    // The JS version sorts at the end, listRefs already sorts.
    // If specific re-sorting after deduplication is needed, do it here.
    // result.sort(compareRefNames);
    return result;
  }
}
