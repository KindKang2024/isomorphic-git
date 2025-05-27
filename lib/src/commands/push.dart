import 'package:isomorphic_git/isomorphic_git.dart';
import '../errors/git_push_error.dart';
import '../errors/missing_parameter_error.dart';
import '../errors/not_found_error.dart';
import '../errors/push_rejected_error.dart';
import '../errors/user_canceled_error.dart';
import '../managers/git_config_manager.dart';
import '../managers/git_ref_manager.dart';
import '../managers/git_remote_manager.dart';
import '../models/git_side_band.dart';
import '../utils/filter_capabilities.dart';
import '../utils/for_await.dart';
import '../utils/pkg.dart';
import '../utils/split_lines.dart';
import '../wire/parse_receive_pack_response.dart';
import '../wire/write_receive_pack_request.dart';

// TODO: replace with actual imports once other files are translated
import '../commands/current_branch.dart' as current_branch_resolver;
import '../commands/find_merge_base.dart' as find_merge_base_resolver;
import '../commands/is_descendent.dart' as is_descendent_resolver;
import '../commands/list_commits_and_tags.dart'
    as list_commits_and_tags_resolver;
import '../commands/list_objects.dart' as list_objects_resolver;
import '../commands/pack.dart' as pack_resolver;
import '../models/git_remote_http.dart'; // Assuming this exists

// TODO: Define these types or import them
typedef FileSystem = dynamic; // Placeholder
typedef Cache = dynamic; // Placeholder
typedef HttpClient = dynamic; // Placeholder
typedef HttpAuth = dynamic; // Placeholder for httpRemote.auth
typedef ProgressCallback = Function(Map<String, dynamic> progress);
typedef MessageCallback = Function(String message);
typedef AuthCallback = Future<dynamic> Function();
typedef AuthFailureCallback = Future<dynamic> Function();
typedef AuthSuccessCallback = Future<dynamic> Function();
typedef PrePushCallback = Future<bool> Function(Map<String, dynamic> params);

class PushResult {
  final bool ok;
  final String? error;
  final Map<String, String>? refs;
  final String? status; // Added based on JS return type
  final List<String>? packfileDelegator; // Added based on JS return type
  final Map<String, String>? results; // Added based on JS return type

  PushResult({
    required this.ok,
    this.error,
    this.refs,
    this.status,
    this.packfileDelegator,
    this.results,
  });

  @override
  String toString() {
    return 'PushResult{ok: $ok, error: $error, refs: $refs, status: $status, results: $results}';
  }
}

Future<PushResult> push({
  required FileSystem fs,
  required Cache cache,
  required HttpClient http,
  ProgressCallback? onProgress,
  MessageCallback? onMessage,
  AuthCallback? onAuth,
  AuthSuccessCallback? onAuthSuccess,
  AuthFailureCallback? onAuthFailure,
  PrePushCallback? onPrePush,
  required String gitdir,
  String? ref,
  String? remoteRef,
  String? remoteIn,
  bool force = false,
  bool delete = false,
  String? urlIn,
  String? corsProxyIn,
  Map<String, String> headers = const {},
}) async {
  String? currentRef = ref;
  if (currentRef == null) {
    // Assuming currentBranch is a function that might return null
    final branch = await current_branch_resolver.currentBranch(
      fs: fs,
      gitdir: gitdir,
      fullname: false,
    );
    if (branch == null) {
      throw MissingParameterError('ref');
    }
    currentRef = branch;
  }

  final config = await GitConfigManager.get(fs: fs, gitdir: gitdir);

  String effectiveRemote =
      remoteIn ??
      await config.get('branch.$currentRef.pushRemote') ??
      await config.get('remote.pushDefault') ??
      await config.get('branch.$currentRef.remote') ??
      'origin';

  String? effectiveUrl =
      urlIn ??
      await config.get('remote.$effectiveRemote.pushurl') ??
      await config.get('remote.$effectiveRemote.url');

  if (effectiveUrl == null) {
    throw MissingParameterError('remote OR url');
  }

  String? effectiveRemoteRefRaw =
      remoteRef ?? await config.get('branch.$currentRef.merge');
  if (effectiveRemoteRefRaw == null) {
    // In JS, this was another check for `url` which seems redundant given the previous check.
    // Dart requires remoteRef to be non-null if not provided, mirroring JS behavior of throwing MissingParameterError.
    throw MissingParameterError('remoteRef');
  }

  String? effectiveCorsProxy =
      corsProxyIn ?? await config.get('http.corsProxy');

  final fullRef = await GitRefManager.expand(
    fs: fs,
    gitdir: gitdir,
    ref: currentRef,
  );
  final oid = delete
      ? '0000000000000000000000000000000000000000'
      : await GitRefManager.resolve(fs: fs, gitdir: gitdir, ref: fullRef);

  final remoteHelper = GitRemoteManager.getRemoteHelperFor(url: effectiveUrl);
  final httpRemote = await remoteHelper.discover(
    http: http,
    onAuth: onAuth,
    onAuthSuccess: onAuthSuccess,
    onAuthFailure: onAuthFailure,
    corsProxy: effectiveCorsProxy,
    service: 'git-receive-pack',
    url: effectiveUrl,
    headers: headers,
    protocolVersion: 1,
  );

  HttpAuth? remoteAuth = httpRemote.auth;

  String fullRemoteRef;
  if (effectiveRemoteRefRaw.isEmpty) {
    // equivalent to !remoteRef in JS for this path
    fullRemoteRef = fullRef;
  } else {
    try {
      fullRemoteRef = await GitRefManager.expandAgainstMap(
        ref: effectiveRemoteRefRaw,
        map: httpRemote.refs,
      );
    } catch (err) {
      if (err is NotFoundError) {
        fullRemoteRef = effectiveRemoteRefRaw.startsWith('refs/')
            ? effectiveRemoteRefRaw
            : 'refs/heads/$effectiveRemoteRefRaw';
      } else {
        rethrow;
      }
    }
  }

  final oldoid =
      httpRemote.refs[fullRemoteRef] ??
      '0000000000000000000000000000000000000000';

  if (onPrePush != null) {
    final hookResult = await onPrePush({
      'remote': effectiveRemote,
      'url': effectiveUrl,
      'localRef': {'ref': delete ? '(delete)' : fullRef, 'oid': oid},
      'remoteRef': {'ref': fullRemoteRef, 'oid': oldoid},
    });
    if (!hookResult) throw UserCanceledError();
  }

  final thinPack = !httpRemote.capabilities.contains('no-thin');
  Set<String> objectsToPack = {};

  if (!delete) {
    List<String> finish = [...httpRemote.refs.values];
    Set<String> skipObjects = {};

    if (oldoid != '0000000000000000000000000000000000000000') {
      final mergeBaseResultDynamic = await find_merge_base_resolver
          .findMergeBase(
            fs: fs,
            cache: cache,
            gitdir: gitdir,
            oids: [oid, oldoid],
          );

      List<String> mergeBases = [];
      if (mergeBaseResultDynamic is List) {
        // Direct list of OIDs
        mergeBases = List<String>.from(
          mergeBaseResultDynamic.map((e) => e.toString()),
        );
      } else if (mergeBaseResultDynamic is Map &&
          mergeBaseResultDynamic.containsKey('mergeBase')) {
        // Map with 'mergeBase' key
        mergeBases = List<String>.from(
          mergeBaseResultDynamic['mergeBase'].map((e) => e.toString()),
        );
      } else if (mergeBaseResultDynamic is String) {
        // Single OID string
        mergeBases = [mergeBaseResultDynamic];
      }

      if (mergeBases.isNotEmpty) {
        finish.addAll(mergeBases);
        if (thinPack) {
          final mbObjects = await list_objects_resolver.listObjects(
            fs: fs,
            cache: cache,
            gitdir: gitdir,
            oids: mergeBases,
          );
          skipObjects.addAll(mbObjects.cast<String>());
        }
      } else {
        print("Warning: findMergeBase did not return usable merge bases.");
      }
    }

    if (!finish.contains(oid)) {
      final commitsDynamic = await list_commits_and_tags_resolver
          .listCommitsAndTags(
            fs: fs,
            cache: cache,
            gitdir: gitdir,
            start: [oid],
            finish: finish,
          );
      // Assuming listCommitsAndTags returns List<String> or similar
      final List<String> commits = List<String>.from(
        commitsDynamic.map((e) => e.toString()),
      );
      objectsToPack = (await list_objects_resolver.listObjects(
        fs: fs,
        cache: cache,
        gitdir: gitdir,
        oids: commits,
      )).cast<String>().toSet();
    }

    if (thinPack) {
      try {
        final remoteHeadRefDynamic = await GitRefManager.resolve(
          fs: fs,
          gitdir: gitdir,
          ref: 'refs/remotes/$effectiveRemote/HEAD',
          depth: 2,
        );

        String? remoteHeadOid;
        // Resolve can return different types, need to handle them.
        // Based on JS, it might be a string (ref name) or an object with 'oid'.
        if (remoteHeadRefDynamic is String) {
          final resolvedRefAgainstMap = await GitRefManager.resolveAgainstMap(
            ref: remoteHeadRefDynamic.replaceFirst(
              'refs/remotes/$effectiveRemote/',
              '',
            ),
            fullref: remoteHeadRefDynamic,
            map: httpRemote.refs,
          );
          if (resolvedRefAgainstMap is Map &&
              resolvedRefAgainstMap.containsKey('oid')) {
            remoteHeadOid = resolvedRefAgainstMap['oid'];
          }
        } else if (remoteHeadRefDynamic is Map &&
            remoteHeadRefDynamic.containsKey('oid')) {
          remoteHeadOid = remoteHeadRefDynamic['oid'];
        }

        if (remoteHeadOid != null) {
          final remoteHeadObjects = await list_objects_resolver.listObjects(
            fs: fs,
            cache: cache,
            gitdir: gitdir,
            oids: [remoteHeadOid],
          );
          skipObjects.addAll(remoteHeadObjects.cast<String>());
        } else {
          print(
            "Optional optimization for thin pack: Could not determine remote HEAD's OID.",
          );
        }
      } catch (e) {
        print("Optional optimization for thin pack failed: $e");
      }
      objectsToPack.removeAll(skipObjects);
    }

    bool localForce = force;
    if (oid == oldoid) localForce = true;
    if (!localForce) {
      if (fullRef.startsWith('refs/tags/') &&
          oldoid != '0000000000000000000000000000000000000000') {
        throw PushRejectedError('tag-exists');
      }
      if (oid != '0000000000000000000000000000000000000000' &&
          oldoid != '0000000000000000000000000000000000000000' &&
          !(await is_descendent_resolver.isDescendent(
            fs: fs,
            cache: cache,
            gitdir: gitdir,
            oid: oid,
            ancestor: oldoid,
            depth: -1,
          ))) {
        throw PushRejectedError('not-fast-forward');
      }
    }
  }

  List<String> capabilities = filterCapabilities(
    [...httpRemote.capabilities],
    ['report-status', 'side-band-64k', 'agent=${pkg.agent}'],
  ).toList();

  final List<Map<String, String>> refUpdates = [
    {'oldoid': oldoid, 'newoid': oid, 'fullRef': fullRemoteRef},
  ];

  Stream<List<int>> packstream = await writeReceivePackRequest(
    capabilities: capabilities,
    refUpdates: refUpdates,
    thinPack: thinPack,
    packObjects: objectsToPack,
    gitdir: gitdir,
    fs: fs,
    cache: cache,
  );

  // This is where _pack was used in JS for onProgress for the pack building phase
  // Dart's packObjects directly takes the set. If _pack had progress, it needs to be integrated into pack_resolver.packObjects
  // For now, we assume pack_resolver.packObjects (which is called by writeReceivePackRequest indirectly) handles its own progress if any.

  final res = await remoteHelper.connect(
    service: 'git-receive-pack',
    auth: remoteAuth,
    url: effectiveUrl,
    corsProxy: effectiveCorsProxy,
    headers: headers,
    body: packstream, // Stream<List<int>>
    http: http,
    onProgress: onProgress, // For upload progress
    onMessage: onMessage, // For side-band messages
  );

  final response = await parseReceivePackResponse(
    res.body,
  ); // res.body is Stream<List<int>>

  if (res.headers != null && res.headers!.containsKey('authentication')) {
    if (onAuthSuccess != null) {
      await onAuthSuccess({
        'url': effectiveUrl,
        'auth': remoteAuth,
      }, res.headers!['authentication']);
    }
  }

  if (!response.ok) {
    String? remoteMessage = response.error;
    throw GitPushError(
      remoteMessage ?? "Unknown push error",
      response.results ?? {},
      res,
    );
  }

  // Update local remote refs
  if (!delete && oid != '0000000000000000000000000000000000000000') {
    await GitRefManager.writeRef(
      fs: fs,
      gitdir: gitdir,
      ref:
          'refs/remotes/$effectiveRemote/${fullRemoteRef.substring('refs/heads/'.length)}', // Adjust if not a head
      value: oid,
    );
  }

  return PushResult(
    ok: true,
    refs: response.refs,
    status: response.status,
    results: response.results,
    // packfileDelegator is not directly mapped from JS, seems to be part of the response parsing
  );
}

// Placeholder for pkg.agent - replace with actual package info access
class Pkg {
  String get agent => 'dart-isomorphic-git/0.0.0'; // Example
}

final pkg = Pkg();
