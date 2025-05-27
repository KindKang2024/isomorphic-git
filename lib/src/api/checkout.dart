// import '../typedefs.dart'; // Dart handles types and callbacks

import '../commands/checkout.dart'
    show checkoutInternal; // Assuming _checkout is checkoutInternal
import '../models/file_system.dart'; // Assumes FsClient is here
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

// Define callback types if they are complex
// typedef ProgressCallback = void Function(dynamic progressEvent);
// typedef PostCheckoutCallback = Future<void> Function();

/// Checkout a branch or paths to the working tree
Future<void> checkout({
  required dynamic fs, // Should be FsClient
  Function? onProgress, // Should be ProgressCallback?
  Function? onPostCheckout, // Should be PostCheckoutCallback?
  required String dir,
  String? gitdir,
  String? ref,
  List<String>? filepaths,
  String remote = 'origin',
  bool noCheckout = false,
  bool? noUpdateHead,
  bool dryRun = false,
  bool force = false,
  bool track = true,
  Map<String, dynamic>? cache,
}) async {
  final effectiveGitdir = gitdir ?? join(dir, '.git');
  final effectiveCache = cache ?? {};
  // Default for noUpdateHead depends on whether ref is provided
  final bool effectiveNoUpdateHead = noUpdateHead ?? (ref == null);
  final String effectiveRef = ref ?? 'HEAD';

  try {
    assertParameter('fs', fs);
    assertParameter('dir', dir);
    assertParameter('gitdir', effectiveGitdir);

    await checkoutInternal(
      fs: FileSystem(fs), // Pass FileSystem instance
      cache: effectiveCache,
      onProgress: onProgress,
      onPostCheckout: onPostCheckout,
      dir: dir,
      gitdir: effectiveGitdir,
      remote: remote,
      ref: effectiveRef,
      filepaths: filepaths,
      noCheckout: noCheckout,
      noUpdateHead: effectiveNoUpdateHead,
      dryRun: dryRun,
      force: force,
      track: track,
    );
  } catch (err) {
    // err.caller = 'git.checkout'; // JS specific
    print("Error in git.checkout: $err");
    rethrow;
  }
}
