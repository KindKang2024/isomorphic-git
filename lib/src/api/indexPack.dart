import '../commands/index_pack.dart' as commands_index_pack;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../typedefs.dart'; // For FsClient, ProgressCallback

class IndexPackResult {
  final List<String> oids;

  IndexPackResult({required this.oids});

  Map<String, dynamic> toJson() => {'oids': oids};
}

Future<IndexPackResult> indexPack({
  required FsClient fs,
  ProgressCallback? onProgress,
  required String dir,
  String? gitdir,
  required String filepath,
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    assertParameter(
      'dir',
      dir,
    ); // dir is required for join below if gitdir is null
    final gd = gitdir ?? join(dir, '.git');
    assertParameter('gitdir', gd);
    assertParameter('filepath', filepath);

    // Assuming _indexPack from commands_index_pack returns an object or Map
    // that directly matches IndexPackResult structure, or just List<String> for oids.
    // The JS returns {oids: string[]}
    final result = await commands_index_pack.indexPack(
      fs: FileSystem(fs),
      cache: cache,
      onProgress: onProgress,
      dir:
          dir, // dir might be needed by _indexPack for resolving filepath if not absolute
      gitdir: gd,
      filepath: filepath,
    );

    // Adapt the result from commands_index_pack.indexPack to IndexPackResult
    if (result is Map) {
      if (result.containsKey('oids') && result['oids'] is List) {
        return IndexPackResult(oids: List<String>.from(result['oids']));
      }
    } else if (result is IndexPackResult) {
      return result;
    } else if (result is List<String>) {
      // If _indexPack just returns the list of oids directly
      return IndexPackResult(oids: result);
    }

    // If the structure is different, this adaptation logic will need to change.
    // For example, if _indexPack directly returns List<String>
    // return IndexPackResult(oids: result as List<String>);
    throw StateError(
      'Unexpected result type from commands_index_pack.indexPack: ${result.runtimeType}',
    );
  } catch (err) {
    // err.caller = 'git.indexPack'
    rethrow;
  }
}
