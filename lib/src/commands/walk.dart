import 'dart:async';

import '../utils/array_range.dart';
import '../utils/flat.dart';
import '../utils/symbols.dart';
import '../utils/union_of_iterators.dart';

// Placeholder for Walker, WalkerMap, WalkerReduce, WalkerIterate, FileSystem types
// These would typically be defined in other files or imported from packages.
typedef Walker = dynamic; // Placeholder
typedef WalkerMap = Future<dynamic> Function(String, List<dynamic>);
typedef WalkerReduce = Future<dynamic> Function(dynamic, List<dynamic>);
typedef WalkerIterate =
    Future<List<dynamic>> Function(
      Future<dynamic> Function(List<dynamic>),
      Iterable<dynamic>,
    );
typedef FileSystem = dynamic; // Placeholder

// Note: The original JS uses a symbol `GitWalkSymbol` to access a method on the `trees`.
// This will need to be adapted based on how `Walker` objects and their methods are defined in Dart.
// For now, I'm assuming `proxy[GitWalkSymbol]` translates to a method call like `proxy.gitWalkSymbol(...)`.
// Also, `ConstructEntry` is assumed to be a method or constructor on the walker instances.

Future<dynamic> walk({
  required FileSystem fs,
  required Map<String, dynamic> cache,
  String? dir,
  String? gitdir,
  required List<Walker> trees,
  WalkerMap? mapFn,
  WalkerReduce? reduceFn,
  WalkerIterate? iterateFn,
}) async {
  // Default map function if not provided
  final map = mapFn ?? (String fullpath, List<dynamic> entry) async => entry;

  // Default reduce function if not provided
  final reduce =
      reduceFn ??
      (dynamic parent, List<dynamic> children) async {
        final flatten = flat(
          children,
        ).toList(); // Assuming flat returns an Iterable
        if (parent != null) flatten.insert(0, parent);
        return flatten;
      };

  // Default iterate function if not provided
  final iterate =
      iterateFn ??
      (
        Future<dynamic> Function(List<dynamic>) walkFn,
        Iterable<dynamic> children,
      ) => Future.wait(children.map((child) => walkFn(child as List<dynamic>)));

  final walkers = trees
      .map(
        (proxy) =>
            proxy.gitWalkSymbol(fs: fs, dir: dir, gitdir: gitdir, cache: cache)
                as dynamic,
      )
      .toList();

  final root = List<String?>.filled(walkers.length, '.');
  final range = arrayRange(0, walkers.length);

  Future<Map<String, dynamic>> unionWalkerFromReaddir(
    List<dynamic> currentEntries,
  ) async {
    var modifiableEntries = List<dynamic>.from(currentEntries);

    for (var i in range) {
      final entry = modifiableEntries[i];
      modifiableEntries[i] = entry != null
          ? walkers[i].ConstructEntry(entry)
          : null;
    }

    final subdirs = await Future.wait(
      range.map((i) {
        final entry = modifiableEntries[i];
        return entry != null
            ? walkers[i].readdir(entry)
            : Future.value(<dynamic>[]);
      }),
    );

    final iterators = subdirs.map((array) {
      return (array == null ? <dynamic>[] : array as List<dynamic>).iterator;
    });

    return {
      'entries': modifiableEntries,
      'children': unionOfIterators(iterators.toList()),
    };
  }

  Future<dynamic> performWalk(List<dynamic> currentRoot) async {
    final result = await unionWalkerFromReaddir(currentRoot);
    final List<dynamic> entries = result['entries']!;
    final Iterable<dynamic> children = result['children']!;

    final fullpathEntry = entries.firstWhere(
      (entry) => entry != null && entry._fullpath != null,
      orElse: () => null,
    );
    final String fullpath = fullpathEntry != null
        ? fullpathEntry._fullpath as String
        : '';

    final parent = await map(fullpath, entries);

    if (parent != null) {
      var walkedChildren = await iterate(
        performWalk,
        children.map((c) => c as List<dynamic>).toList(),
      );
      walkedChildren = walkedChildren.where((x) => x != null).toList();
      return reduce(parent, walkedChildren);
    }
    return null;
  }

  return performWalk(root.map((e) => e as dynamic).toList());
}
