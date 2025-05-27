import '../commands/find_merge_base.dart' as commands_find_merge_base;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // Assuming FsClient is defined here

Future<List<String>> findMergeBase({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required List<String> oids,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    final gd = gitdir ?? (dir != null ? join(dir, '.git') : null);
    assertParameter('gitdir', gd);
    assertParameter('oids', oids);

    // Assuming _findMergeBase returns a list of strings (oids)
    final result = await commands_find_merge_base.findMergeBase(
      fs: FileSystem(fs),
      cache: cache,
      gitdir: gd!,
      oids: oids,
    );
    // The original JS code doesn't specify the return type of _findMergeBase explicitly in the snippet.
    // Based on the context of "merge base", it usually returns one or more commit OIDs.
    // If it returns a single OID, this should be Future<String> and the call adjusted.
    // If it can return multiple, List<String> is appropriate.
    // For now, assuming it can return multiple, so List<String>.
    if (result is String) {
      return [result];
    }
    if (result is List) {
      return result.map((item) => item.toString()).toList();
    }
    // Fallback or error if the type is unexpected, though the JS version doesn't show this handling.
    // Dart requires more explicit type handling.
    if (result == null) return [];
    return [
      result.toString(),
    ]; // Or throw an error if a list is strictly expected
  } catch (err) {
    // Consider custom exception for err.caller
    rethrow;
  }
}
