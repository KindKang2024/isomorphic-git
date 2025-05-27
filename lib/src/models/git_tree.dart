import 'dart:typed_data';
import 'dart:convert';

import '../errors/internal_error.dart';
import '../errors/unsafe_filepath_error.dart';
import '../utils/compare_path.dart'; // Placeholder
import '../utils/compare_tree_entry_path.dart'; // Placeholder

enum GitObjectType { commit, blob, tree, unknown }

class TreeEntry {
  String mode;
  String path;
  String oid;
  GitObjectType type;

  TreeEntry({
    required this.mode,
    required this.path,
    required this.oid,
    required this.type,
  });

  @override
  String toString() {
    return '$mode ${type.name} $oid\t$path';
  }
}

GitObjectType _mode2type(String mode) {
  switch (mode) {
    case '040000':
      return GitObjectType.tree;
    case '100644': // regular file
    case '100755': // executable file
    case '120000': // symlink
      return GitObjectType.blob;
    case '160000': // submodule
      return GitObjectType.commit;
    default:
      throw InternalError('Unexpected GitTree entry mode: $mode');
  }
}

String _limitModeToAllowed(String modeStr) {
  // In JS, mode could be a number, convert to string if so (though Dart will likely enforce String)
  // final modeStr = mode is num ? mode.toRadixString(8) : mode.toString();

  if (modeStr.startsWith('4') || modeStr.startsWith('04')) return '040000'; // Directory
  if (modeStr.startsWith('1006')) return '100644'; // Regular non-executable file
  if (modeStr.startsWith('1007')) return '100755'; // Regular executable file
  if (modeStr.startsWith('120')) return '120000'; // Symbolic link
  if (modeStr.startsWith('160')) return '160000'; // Commit (git submodule reference)
  throw InternalError('Could not understand file mode: $modeStr');
}

TreeEntry _nudgeIntoShape(Map<String, dynamic> rawEntry) {
  String oid = rawEntry['oid'] ?? rawEntry['sha']; // Github uses 'sha'
  String mode = _limitModeToAllowed(rawEntry['mode'].toString());
  GitObjectType type = rawEntry['type'] != null 
      ? GitObjectType.values.firstWhere((e) => e.name == rawEntry['type'], orElse: () => _mode2type(mode))
      : _mode2type(mode);
  String path = rawEntry['path'];

  return TreeEntry(mode: mode, path: path, oid: oid, type: type);
}

class GitTree implements Iterable<TreeEntry> {
  late List<TreeEntry> _entries;

  GitTree(dynamic entries) {
    if (entries is Uint8List) {
      _entries = _parseBuffer(entries);
    } else if (entries is List) {
      _entries = entries.map((e) => _nudgeIntoShape(e as Map<String, dynamic>)).toList();
    } else {
      throw InternalError('Invalid type passed to GitTree constructor: ${entries.runtimeType}');
    }
    // Ensure sorting by path for consistent behavior as in JS version
    _entries.sort((a, b) => comparePath(a.path, b.path)); // comparePath needs to be implemented
  }

  static GitTree from(dynamic tree) {
    return GitTree(tree);
  }

  List<TreeEntry> _parseBuffer(Uint8List buffer) {
    final entries = <TreeEntry>[];
    int cursor = 0;
    while (cursor < buffer.length) {
      final space = buffer.indexOf(32, cursor); // ASCII for space
      if (space == -1) {
        throw InternalError(
            'GitTree: Error parsing buffer at byte location $cursor: Could not find the next space character.');
      }
      final nullchar = buffer.indexOf(0, cursor); // ASCII for null
      if (nullchar == -1) {
        throw InternalError(
            'GitTree: Error parsing buffer at byte location $cursor: Could not find the next null character.');
      }

      String mode = utf8.decode(buffer.sublist(cursor, space));
      if (mode == '40000') mode = '040000'; // Normalize mode

      final type = _mode2type(mode);
      final path = utf8.decode(buffer.sublist(space + 1, nullchar));

      if (path.contains('\\') || path.contains('/')) {
         throw UnsafeFilepathError(path);
      }

      final oid = hex.encode(buffer.sublist(nullchar + 1, nullchar + 21));
      cursor = nullchar + 21;
      entries.add(TreeEntry(mode: mode, path: path, oid: oid, type: type));
    }
    return entries;
  }

  String render() {
    return _entries.map((entry) => entry.toString()).join('\n');
  }

  Uint8List toObject() {
    // Sort entries according to Git's specific tree object rules before serializing
    final sortedEntries = List<TreeEntry>.from(_entries);
    sortedEntries.sort((a,b) => compareTreeEntryPath(a,b)); // compareTreeEntryPath needs to be implemented

    final List<Uint8List> buffers = [];
    for (final entry in sortedEntries) {
      final modeBuffer = utf8.encode(entry.mode.startsWith('0') ? entry.mode.substring(1) : entry.mode);
      final spaceBuffer = Uint8List.fromList([32]); // space
      final pathBuffer = utf8.encode(entry.path);
      final nullBuffer = Uint8List.fromList([0]); // null terminator
      final oidBuffer = Uint8List.fromList(hex.decode(entry.oid));
      buffers.add(Uint8List.fromList([
        ...modeBuffer,
        ...spaceBuffer,
        ...pathBuffer,
        ...nullBuffer,
        ...oidBuffer,
      ]));
    }
    return Uint8List.fromList(buffers.expand((x) => x).toList());
  }

  List<TreeEntry> entries() => _entries;

  @override
  Iterator<TreeEntry> get iterator => _entries.iterator;
}