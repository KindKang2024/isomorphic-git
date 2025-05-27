import 'dart:io';

import '../commands/checkout.dart';
import '../commands/current_branch.dart';
import '../commands/fetch.dart';
import '../commands/merge.dart';
import '../errors/missing_parameter_error.dart';
import '../models/commit_author.dart';
import '../models/http_client.dart';
import '../typedefs.dart';

Future<void> pull({
  required Directory fs,
  required dynamic cache,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthFailureCallback? onAuthFailure,
  AuthSuccessCallback? onAuthSuccess,
  required String dir,
  required String gitdir,
  String? ref,
  String? url,
  String? remote,
  String? remoteRef,
  bool? prune,
  bool? pruneTags,
  String? corsProxy,
  required bool singleBranch,
  required bool fastForward,
  required bool fastForwardOnly,
  Map<String, String>? headers,
  required CommitAuthor author,
  required CommitAuthor committer,
  String? signingKey,
}) async {
  try {
    ref ??= await currentBranch(fs: fs, gitdir: gitdir);
    if (ref == null) {
      throw MissingParameterError('ref');
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
      corsProxy: corsProxy,
      ref: ref,
      url: url,
      remote: remote,
      remoteRef: remoteRef,
      singleBranch: singleBranch,
      headers: headers,
      prune: prune,
      pruneTags: pruneTags,
    );

    await merge(
      fs: fs,
      cache: cache,
      gitdir: gitdir,
      ours: ref,
      theirs: fetchResult.fetchHead!,
      fastForward: fastForward,
      fastForwardOnly: fastForwardOnly,
      message: 'Merge ${fetchResult.fetchHeadDescription}',
      author: author,
      committer: committer,
      signingKey: signingKey,
      dryRun: false,
      noUpdateBranch: false,
    );

    await checkout(
      fs: fs,
      cache: cache,
      onProgress: onProgress,
      dir: dir,
      gitdir: gitdir,
      ref: ref,
      remote: remote,
      noCheckout: false,
    );
  } catch (e) {
    // Consider how to handle caller in Dart. Maybe wrap in a custom exception?
    rethrow;
  }
}
