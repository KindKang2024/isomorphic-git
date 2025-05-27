// Assuming InternalError is available or will be ported.
// import '../errors/internal_error.dart'; // Placeholder

class InternalError extends Error {
  final String message;
  InternalError(this.message);
  @override
  String toString() => 'InternalError: $message';
}

class GitRefSpec {
  final String remotePath;
  final String localPath;
  final bool force;
  final bool matchPrefix;

  GitRefSpec({
    required this.remotePath,
    required this.localPath,
    required this.force,
    required this.matchPrefix,
  });

  static GitRefSpec from(String refspec) {
    final RegExp pattern = RegExp(r'^(\+?)(.*?)(\*?):(.*?)(\*?)$');
    final Match? match = pattern.firstMatch(refspec);

    if (match == null || match.groupCount < 5) {
      throw InternalError('Invalid refspec format: $refspec');
    }

    final String forceMatch = match.group(1) ?? '';
    final String remotePathPart = match.group(2) ?? '';
    final String remoteGlobMatch = match.group(3) ?? '';
    final String localPathPart = match.group(4) ?? '';
    final String localGlobMatch = match.group(5) ?? '';

    final bool force = forceMatch == '+';
    final bool remoteIsGlob = remoteGlobMatch == '*';
    final bool localIsGlob = localGlobMatch == '*';

    // validate
    // TODO: Make this check more nuanced, and depend on whether this is a fetch refspec or a push refspec
    if (remoteIsGlob != localIsGlob) {
      throw InternalError(
          'Invalid refspec: $refspec. Remote and local parts must both be globs or neither.');
    }

    return GitRefSpec(
      remotePath: remotePathPart,
      localPath: localPathPart,
      force: force,
      matchPrefix: remoteIsGlob, // if it's a glob, it implies prefix matching for the non-glob part
    );
    // TODO: We need to run resolveRef on both paths to expand them to their full name.
  }

  String? translate(String remoteBranch) {
    if (matchPrefix) {
      if (remoteBranch.startsWith(remotePath)) {
        return localPath + remoteBranch.substring(remotePath.length);
      }
    } else {
      if (remoteBranch == remotePath) return localPath;
    }
    return null;
  }

  String? reverseTranslate(String localBranch) {
    if (matchPrefix) {
      if (localBranch.startsWith(localPath)) {
        return remotePath + localBranch.substring(localPath.length);
      }
    } else {
      if (localBranch == localPath) return remotePath;
    }
    return null;
  }
}