import '../models/file_system.dart';
import '../models/running_minimum.dart';
import '../utils/array_range.dart';
import '../utils/flat.dart';
import '../utils/union_of_iterators.dart';
import '../utils/symbols.dart';

/// Walker interface - represents a tree walker that can traverse git objects
abstract class Walker {
  /// Constructor function for creating walker entries
  WalkerEntry Function(String fullpath) get constructEntry;
  
  /// Read directory entries for a given walker entry
  Future<List<String>?> readdir(WalkerEntry entry);
}

/// Walker entry interface - represents an entry in a walker
abstract class WalkerEntry {
  String get fullpath;
  Future<String?> type();
  Future<int?> mode();
  Future<dynamic> stat();
  Future<List<int>?> content();
  Future<String?> oid();
}

/// Function type for mapping walker entries
typedef WalkerMap = Future<dynamic> Function(String? fullpath, List<WalkerEntry?> entries);

/// Function type for reducing walker results
typedef WalkerReduce = Future<dynamic> Function(dynamic parent, List<dynamic> children);

/// Function type for iterating over walker children
typedef WalkerIterate = Future<List<dynamic>> Function(
  Future<dynamic> Function(List<String>) walk,
  Stream<List<String?>> children,
);

/// Internal walk function that traverses git trees using walkers
/// 
/// [fs] - File system interface
/// [cache] - Cache object for optimization
/// [dir] - Working directory path
/// [gitdir] - Git directory path (defaults to join(dir, '.git'))
/// [trees] - List of walker objects to traverse
/// [map] - Optional mapping function for entries
/// [reduce] - Optional reduction function for combining results
/// [iterate] - Optional iteration function for walking children
/// 
/// Returns the finished tree-walking result
Future<dynamic> walk({
  required FileSystem fs,
  required Map<String, dynamic> cache,
  String? dir,
  String? gitdir,
  required List<Walker> trees,
  WalkerMap? map,
  WalkerReduce? reduce,
  WalkerIterate? iterate,
}) async {
  // Default map function - returns the entry as-is
  map ??= (String? _, List<WalkerEntry?> entry) async => entry;
  
  // Default reduce function - flattens children and prepends parent
  reduce ??= (dynamic parent, List<dynamic> children) async {
    final flatten = flat(children.cast<List<dynamic>>());
    if (parent != null) {
      flatten.insert(0, parent);
    }
    return flatten;
  };
  
  // Default iterate function - processes all children concurrently
  iterate ??= (Future<dynamic> Function(List<String>) walk, Stream<List<String?>> children) async {
    final results = <dynamic>[];
    await for (final child in children) {
      final result = await walk(child.whereType<String>().toList());
      results.add(result);
    }
    return results;
  };
  
  // Create walker instances using the GitWalkSymbol pattern
  final walkers = <Walker>[];
  for (final proxy in trees) {
    // In Dart, we'll assume the Walker objects are already properly constructed
    // since we don't have the exact equivalent of JavaScript's symbol-based dispatch
    walkers.add(proxy);
  }
  
  final root = List<String>.filled(walkers.length, '.');
  final range = arrayRange(0, walkers.length);
  
  Future<({List<WalkerEntry?> entries, Stream<List<String?>> children})> unionWalkerFromReaddir(
    List<String> entries,
  ) async {
    final walkerEntries = <WalkerEntry?>[]; 
    
    // Create walker entries for each walker
    for (int i in range) {
      final entry = i < entries.length ? entries[i] : null;
      walkerEntries.add(entry != null ? walkers[i].constructEntry(entry) : null);
    }
    
    // Read subdirectories for each walker entry
    final subdirs = <List<String>>[];
    for (int i in range) {
      final entry = walkerEntries[i];
      final subdir = entry != null ? await walkers[i].readdir(entry) : <String>[];
      subdirs.add(subdir ?? <String>[]);
    }
    
    // Process child directories
    final iterators = subdirs.map((array) {
      return array.iterator;
    }).toList();
    
    return (
      entries: walkerEntries,
      children: unionOfIterators(iterators),
    );
  }
  
  Future<dynamic> walkInternal(List<String> root) async {
    final result = await unionWalkerFromReaddir(root);
    final entries = result.entries;
    final children = result.children;
    
    // Find the fullpath from the first non-null entry
    String? fullpath;
    for (final entry in entries) {
      if (entry?.fullpath != null) {
        fullpath = entry!.fullpath;
        break;
      }
    }
    
    final parent = await map!(fullpath, entries);
    if (parent != null) {
      final walkedChildren = await iterate!(walkInternal, children);
      final filteredChildren = walkedChildren.where((x) => x != null).toList();
      return reduce!(parent, filteredChildren);
    }
    return null;
  }
  
  return walkInternal(root);
}