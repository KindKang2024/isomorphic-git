/// A pure Dart implementation of Git operations.
/// 
/// This library provides Git functionality similar to isomorphic-git,
/// allowing you to perform Git operations in pure Dart.
library dart_git;

// Core API exports
export 'src/api/add.dart';
export 'src/api/branch.dart';
export 'src/api/checkout.dart';
export 'src/api/clone.dart';
export 'src/api/commit.dart';
export 'src/api/config.dart';
export 'src/api/fetch.dart';
export 'src/api/init.dart';
export 'src/api/log.dart';
export 'src/api/merge.dart';
export 'src/api/pull.dart';
export 'src/api/push.dart';
export 'src/api/status.dart';
export 'src/api/tag.dart';

// Error exports
export 'src/errors/git_errors.dart';

// Model exports
export 'src/models/git_commit.dart';
export 'src/models/git_tree.dart';
export 'src/models/git_blob.dart';
export 'src/models/git_tag.dart';

// Utility exports
export 'src/utils/git_utils.dart';

// Constants
export 'src/constants.dart';
