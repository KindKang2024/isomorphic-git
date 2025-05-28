import 'dart:async';
import 'dart:typed_data';

import '../errors/not_found_error.dart'; // Placeholder
import '../errors/object_type_error.dart'; // Placeholder
import '../managers/git_ref_manager.dart'; // Placeholder
import './git_tree.dart'; // Assumes GitTree and TreeEntry are defined
import '../storage/read_object.dart'; // Placeholder for _readObject
import '../utils/normalize_mode.dart'; // Placeholder
import '../utils/resolve_tree.dart'; // Placeholder
import '../models/file_system.dart'; // Assuming an abstract FileSystem interface
import './git_walker_fs.dart'; // For WalkerEntry
import '../utils/join.dart'; // For join function

// Define ReadObjectResult if not already present
// class ReadObjectResult {
//   String oid;
//   String type; // 'blob', 'tree', 'commit', 'tag'
//   Uint8List object;
//   String? format;
// }

class GitWalkerRepo {
  final FileSystem fs;
  final Map<String, dynamic> cache;
  final String gitdir;
  final Future<Map<String, TreeEntry>> mapPromise; // Map path to TreeEntry

  late final WalkerEntry Function(String fullpath) constructEntry;

  GitWalkerRepo({
    required this.fs,
    required this.gitdir,
    required String ref,
    required this.cache,
  }) : mapPromise = _initializeMap(fs, gitdir, ref, cache) {
    final walker = this;
    constructEntry = (String fullpath) => _RepoEntry(walker, fullpath);
  }

  static Future<Map<String, TreeEntry>> _initializeMap(
    FileSystem fs,
    String gitdir,
    String ref,
    Map<String, dynamic> cache,
  ) async {
    final map = <String, TreeEntry>{};
    String oid;
    try {
      oid = await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: ref);
    } on NotFoundError {
      // Handle fresh branches with no commits - use empty tree OID
      oid = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
    }
    // resolveTree should return a structure that can be converted to TreeEntry
    // Or it returns a root TreeEntry itself.
    // The JS version sets tree.type and tree.mode on the resolved tree object.
    final resolvedTree = await resolveTree(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: oid,
    );

    // Assuming resolvedTree is a TreeEntry or can be made into one
    // For simplicity, let's assume resolveTree gives us the root TreeEntry's properties
    // and we manually create the root entry for the map.
    map['.'] = TreeEntry(
      mode: resolvedTree.mode ?? '040000', // Default to tree mode
      path: '.',
      oid:
          resolvedTree.oid ??
          oid, // Use resolved OID or original if tree was empty
      type: GitObjectType.values.firstWhere(
        (e) => e.name == (resolvedTree.type ?? 'tree'),
      ),
    );
    return map;
  }

  Future<List<String>?> readdirImpl(WalkerEntry entry) async {
    final filepath = entry.fullpath;
    final map = await mapPromise;
    final obj = map[filepath];

    if (obj == null) throw Exception('No obj for $filepath');
    final oid = obj.oid;
    if (obj.type != GitObjectType.tree) {
      // TODO: support submodules (type === GitObjectType.commit)
      return null;
    }

    final readResult = await readObject(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      oid: oid,
    );
    if (readResult.type != 'tree') {
      throw ObjectTypeError(oid, readResult.type, 'tree');
    }

    final tree = GitTree(readResult.object);
    for (final treeEntry in tree) {
      map[join(filepath, treeEntry.path)] = treeEntry;
    }
    return tree.entries().map((e) => join(filepath, e.path)).toList();
  }

  Future<String?> typeImpl(WalkerEntry entry) async {
    final e = entry as _RepoEntry;
    if (e._type == null) {
      final map = await mapPromise;
      final obj = map[e.fullpath];
      e._type = obj?.type.name;
    }
    return e._type;
  }

  Future<int?> modeImpl(WalkerEntry entry) async {
    final e = entry as _RepoEntry;
    if (e._mode == null) {
      final map = await mapPromise;
      final obj = map[e.fullpath];
      if (obj != null) {
        e._mode = normalizeMode(
          int.parse(obj.mode, radix: 16),
        ); // normalizeMode needs implementation
      }
    }
    return e._mode;
  }

  Future<dynamic> statImpl(WalkerEntry entry) async {
    // Stat isn't directly applicable/retrieved in the same way for repo objects
    return null;
  }

  Future<Uint8List?> contentImpl(WalkerEntry entry) async {
    final e = entry as _RepoEntry;
    if (e._content == null) {
      final map = await mapPromise;
      final obj = map[e.fullpath];
      if (obj == null || obj.type != GitObjectType.blob) {
        e._content = null; // Explicitly null for Uint8List?
      } else {
        final readResult = await readObject(
          fs: fs,
          cache: cache,
          gitdir: gitdir,
          oid: obj.oid,
        );
        if (readResult.type != 'blob') {
          e._content = null; // Or throw error
        } else {
          e._content = readResult.object;
        }
      }
    }
    return e._content;
  }

  Future<String?> oidImpl(WalkerEntry entry) async {
    final e = entry as _RepoEntry;
    if (e._oid == null) {
      final map = await mapPromise;
      final obj = map[e.fullpath];
      e._oid = obj?.oid;
    }
    return e._oid;
  }
}

class _RepoEntry implements WalkerEntry {
  final GitWalkerRepo _walker;
  @override
  final String fullpath;

  String? _type;
  int? _mode;
  // _stat is not used for repo walker
  Uint8List? _content;
  String? _oid;

  _RepoEntry(this._walker, this.fullpath);

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
