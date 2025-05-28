import 'dart:async';
import 'dart:typed_data';
import 'dart:io'; // Added for FileSystemEntityType, Directory, FileStat

import '../managers/git_config_manager.dart'; // Placeholder
import '../managers/git_index_manager.dart'; // Placeholder
import '../utils/compare_stats.dart'; // Placeholder
import '../utils/normalize_stats.dart'; // Placeholder
import '../utils/shasum.dart'; // Placeholder
import '../utils/join.dart'; // Added for join utility
import './git_object.dart';
import '../models/file_system.dart'; // Assuming an abstract FileSystem interface
import '../models/git_config.dart'; // Added for GitConfig type

// Define an abstract FileSystem interface if not already present
// abstract class FileSystem {
//   Future<List<String>?> readdir(String path);
//   Future<dynamic> lstat(String path); // dynamic can be a custom Stat object
//   Future<Uint8List> read(String path, {String? encoding, bool? autocrlf});
//   // ... other methods
// }

// Define a Stat class if not already present
// class Stat {
//   bool isDirectory();
//   bool isFile();
//   bool isSymbolicLink();
//   int mode;
//   int size;
//   // ... other properties
// }

abstract class WalkerEntry {
  String get fullpath;
  Future<String?> type();
  Future<int?> mode();
  Future<dynamic> stat(); // Replace dynamic with your Stat class
  Future<Uint8List?> content();
  Future<String?> oid();
}

class GitWalkerFs {
  final FileSystem fs;
  final Map<String, dynamic> cache; // Define cache structure if needed
  final String dir; // workdir path
  final String gitdir;
  GitConfig? _config;

  late final WalkerEntry Function(String fullpath) constructEntry;

  GitWalkerFs({
    required this.fs,
    required this.dir,
    required this.gitdir,
    required this.cache,
  }) {
    final walker = this;
    constructEntry = (String fullpath) => _WorkdirEntry(walker, fullpath);
  }

  Future<List<String>?> readdirImpl(WalkerEntry entry) async {
    final filepath = entry.fullpath;
    final names = await fs.readdir(join(dir, filepath));
    if (names == null) return null;
    return names.map((name) => join(filepath, name)).toList();
  }

  Future<String?> typeImpl(WalkerEntry entry) async {
    final e = entry as _WorkdirEntry;
    if (e._type == null) {
      await statImpl(e);
    }
    return e._type;
  }

  Future<int?> modeImpl(WalkerEntry entry) async {
    final e = entry as _WorkdirEntry;
    if (e._mode == null) {
      await statImpl(e);
    }
    return e._mode;
  }

  Future<dynamic> statImpl(WalkerEntry entry) async {
    final e = entry as _WorkdirEntry;
    if (e._stat == null) {
      // Assume fs.lstat returns a dart:io.FileStat or a compatible object.
      // If fs.lstat() is defined to return `dynamic`, an explicit cast might be needed
      // if the analyzer can't infer FileStat.
      final statFs = await fs.lstat(join(dir, e.fullpath));

      // Ensure statFs is not null before proceeding
      if (statFs == null) {
        throw Exception(
          'ENOENT: no such file or directory, lstat '${e.fullpath}'',
        );
      }
      
      // Ensure statFs is a FileStat object before accessing .type
      // This check is important if fs.lstat can return other types or if it's dynamic.
      if (statFs is! FileStat) {
        throw Exception('Invalid stat object received from fs.lstat for ${e.fullpath}. Expected FileStat, got ${statFs.runtimeType}');
      }
      final statData = statFs as FileStat;


      String type;
      if (statData.type == FileSystemEntityType.directory) {
        type = 'tree';
      } else if (statData.type == FileSystemEntityType.file) {
        type = 'blob';
      } else if (statData.type == FileSystemEntityType.link) {
        type = 'blob'; // Symbolic links are treated as 'blob' type in JS example
      } else {
        type = 'special'; // Other types (fifo, socket, etc.)
      }
      e._type = type;

      // normalizeStats is expected to return Map<String, dynamic>
      // It takes the original FileStat object as input.
      final normalizedStatMap = normalizeStats(statData);

      e._mode = normalizedStatMap['mode'] as int?;
      if ((normalizedStatMap['size'] as int?) == -1 && e._actualSize != null) {
        normalizedStatMap['size'] = e._actualSize; // Modifying the map
      }
      e._stat = normalizedStatMap; // _stat is dynamic, so Map is fine
    }
    return e._stat;
  }

  Future<Uint8List?> contentImpl(WalkerEntry entry) async {
    final e = entry as _WorkdirEntry;
    if (e._content == null) {
      if (await typeImpl(e) == 'tree') {
        e._content = null; // Explicitly null for Uint8List?
      } else {
        final config = await _getGitConfig();
        final autocrlf =
            await config.get('core.autocrlf') as bool? ?? false;
        final fileContent = await fs.read(
          join(dir, e.fullpath),
          autocrlf: autocrlf,
        );
        e._actualSize = fileContent?.lengthInBytes; // Null-safe access
        if (e._stat != null && (e._stat['size'] as int?) == -1 && e._actualSize != null) { // Access size from map
          // e._stat.size = e._actualSize; // This would modify the stat object, ensure it's mutable or handle differently
          // If _stat is a map, modify it:
           e._stat['size'] = e._actualSize;
        }
        e._content = fileContent;
      }
    }
    return e._content;
  }

  Future<String?> oidImpl(WalkerEntry entry) async {
    final e = entry as _WorkdirEntry;
    if (e._oid == null) {
      String? calculatedOid;
      await GitIndexManager.acquire(
        fs: Directory(gitdir), // Changed to Directory(gitdir)
        gitdir: gitdir,        // Pass gitdir explicitly
        closure: (index) async { // Changed callback to closure
          final stageEntry = index.entriesMap[e.fullpath];
          final stats = await statImpl(e); // This is now a Map
          final config = await _getGitConfig();
          final filemode =
              await config.get('core.filemode') as bool? ?? true;
          final trustino = true; // Simplified for now

          // compareStats now takes 2 arguments in Dart (assumed)
          if (stageEntry == null ||
              compareStats(stats, stageEntry)) { 
            final fileContent = await contentImpl(e);
            if (fileContent == null) {
              calculatedOid = null;
            } else {
              calculatedOid = await shasum(
                GitObject.wrap(type: 'blob', object: fileContent),
              );
              // stats is a Map, stageEntry.mode and stageEntry.oid are compared
              // Ensure stats from statImpl() (which is a Map) has 'mode'
              if (stageEntry != null &&
                  calculatedOid == stageEntry.oid &&
                  (!filemode || (stats['mode'] as int?) == stageEntry.mode) &&
                  compareStats(stats, stageEntry)) { // compareStats takes 2 args
                index.insert(
                  filepath: e.fullpath,
                  stats: stats, // Pass the map
                  oid: calculatedOid!,
                );
              }
            }
          } else {
            calculatedOid = stageEntry.oid;
          }
        },
      );
      e._oid = calculatedOid;
    }
    return e._oid;
  }

  Future<GitConfig> _getGitConfig() async {
    _config ??= await GitConfigManager.get(fs: Directory(gitdir), gitdir: gitdir); // Changed fs to Directory(gitdir)
    return _config!;
  }
}

class _WorkdirEntry implements WalkerEntry {
  final GitWalkerFs _walker;
  @override
  final String fullpath;

  String? _type;
  int? _mode;
  dynamic _stat; // Replace with Stat class
  Uint8List? _content;
  String? _oid;
  int? _actualSize; // For BrowserFS workaround

  _WorkdirEntry(this._walker, this.fullpath);

  @override
  Future<String?> type() => _walker.typeImpl(this);
  @override
  Future<int?> mode() => _walker.modeImpl(this);
  @override
  Future<dynamic> stat() => _walker.statImpl(this);
  @override
  Future<Uint8List?> content() => _walker.contentImpl(this);
  @override
  Future<String?> oid() => _walker.oidImpl(this);
}
