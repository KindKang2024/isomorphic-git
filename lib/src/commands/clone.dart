import 'dart:io';

import '../commands/add_remote.dart';
import '../commands/checkout.dart';
import '../commands/fetch.dart';
import '../commands/init.dart';
import '../managers/git_config_manager.dart';
import '../models/file_system.dart';
import '../models/http_client.dart';
import '../utils/callbacks.dart';

Future<void> clone({
  required FileSystem fs,
  required dynamic cache,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthFailureCallback? onAuthFailure,
  AuthSuccessCallback? onAuthSuccess,
  PostCheckoutCallback? onPostCheckout,
  String? dir,
  required String gitdir,
  required String url,
  String? corsProxy,
  String? ref,
  bool? singleBranch,
  bool? noCheckout,
  bool? noTags,
  String? remote = 'origin',
  int? depth,
  DateTime? since,
  List<String>? exclude,
  bool? relative,
  Map<String, String>? headers,
}) async {
  try {
    await init(fs: fs, gitdir: gitdir);
    await addRemote(
      fs: fs,
      gitdir: gitdir,
      remote: remote!,
      url: url,
      force: false,
    );
    if (corsProxy != null) {
      var config = await GitConfigManager.get(fs: fs, gitdir: gitdir);
      await config.set('http.corsProxy', corsProxy);
      await GitConfigManager.save(fs: fs, gitdir: gitdir, config: config);
    }

    final fetchResult = await fetch(
      fs: fs,
      cache: cache,
      http: http,
      onProgress: onProgress,
      onMessage: onMessage,
      onAuth: onAuth,
      onAuthSuccess: onAuthSuccess,
      onAuthFailure: onAuthFailure,
      gitdir: gitdir,
      ref: ref,
      remote: remote,
      corsProxy: corsProxy,
      depth: depth,
      since: since,
      exclude: exclude,
      relative: relative,
      singleBranch: singleBranch,
      headers: headers,
      tags: !(noTags ?? false),
    );

    if (fetchResult.fetchHead == null) return;

    ref = ref ?? fetchResult.defaultBranch;
    ref = ref?.replaceFirst(RegExp(r'refs/heads/'), '');

    await checkout(
      fs: fs,
      cache: cache,
      onProgress: onProgress,
      onPostCheckout: onPostCheckout,
      dir: dir,
      gitdir: gitdir,
      ref: ref,
      remote: remote,
      noCheckout: noCheckout,
    );
  } catch (err) {
    try {
      // Remove partial local repository, see #1283
      // Ignore any error as we are already failing.
      // The catch is necessary so the original error is not masked.
      await fs.rmdir(gitdir, recursive: true, maxRetries: 10);
    } catch (_) {}
    rethrow;
  }
}
