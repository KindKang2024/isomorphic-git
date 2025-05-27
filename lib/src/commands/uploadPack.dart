import 'dart:async';
import 'dart:typed_data';

import '../managers/git_ref_manager.dart';
import '../utils/join.dart';
import '../wire/write_refs_ad_response.dart';
// Assuming FileSystem is defined elsewhere, possibly in a shared types file or from a package
// For now, using `dynamic` as a placeholder.
// import '../models/file_system.dart';

Future<Uint8List?> uploadPack({
  required dynamic fs, // FileSystem fs,
  String? dir,
  String? gitdir,
  bool advertiseRefs = false,
}) async {
  gitdir ??= dir != null
      ? join(dir, '.git')
      : '.git'; // Default to .git if dir is also null

  try {
    if (advertiseRefs) {
      // Send a refs advertisement
      final capabilities = [
        'thin-pack',
        'side-band',
        'side-band-64k',
        'shallow',
        'deepen-since',
        'deepen-not',
        'allow-tip-sha1-in-want',
        'allow-reachable-sha1-in-want',
      ];
      List<String> keys = await GitRefManager.listRefs(
        fs: fs,
        gitdir: gitdir,
        filepath: 'refs',
      );
      keys = keys.map((ref) => 'refs/$ref').toList();
      final refs = <String, String>{};
      keys.insert(0, 'HEAD'); // HEAD must be the first in the list
      for (final key in keys) {
        refs[key] = await GitRefManager.resolve(
          fs: fs,
          gitdir: gitdir,
          ref: key,
        );
      }
      final symrefs = <String, String>{};
      symrefs['HEAD'] = await GitRefManager.resolve(
        fs: fs,
        gitdir: gitdir,
        ref: 'HEAD',
        depth: 2,
      );
      return writeRefsAdResponse(
        capabilities: capabilities,
        refs: refs,
        symrefs: symrefs,
      );
    }
    return null; // Or throw an error if advertiseRefs is expected to be true
  } catch (e) {
    // Consider a more specific error handling or rethrowing strategy
    print('Error in git.uploadPack: $e');
    rethrow;
  }
}
