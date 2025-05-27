/// Git-specific error classes
library;

/// Base class for all Git errors
abstract class GitError implements Exception {
  const GitError(this.message, {this.code});
  
  final String message;
  final String? code;
  
  @override
  String toString() => 'GitError: $message';
}

/// Error thrown when a Git object is not found
class NotFoundError extends GitError {
  const NotFoundError(super.message, {super.code = 'NotFoundError'});
  
  @override
  String toString() => 'NotFoundError: $message';
}

/// Error thrown when a required parameter is missing
class MissingParameterError extends GitError {
  const MissingParameterError(super.message, {super.code = 'MissingParameterError'});
  
  @override
  String toString() => 'MissingParameterError: $message';
}

/// Error thrown when an invalid OID is provided
class InvalidOidError extends GitError {
  const InvalidOidError(super.message, {super.code = 'InvalidOidError'});
  
  @override
  String toString() => 'InvalidOidError: $message';
}

/// Error thrown when an invalid reference name is provided
class InvalidRefNameError extends GitError {
  const InvalidRefNameError(super.message, {super.code = 'InvalidRefNameError'});
  
  @override
  String toString() => 'InvalidRefNameError: $message';
}

/// Error thrown when a merge conflict occurs
class MergeConflictError extends GitError {
  const MergeConflictError(super.message, {super.code = 'MergeConflictError'});
  
  @override
  String toString() => 'MergeConflictError: $message';
}

/// Error thrown when there are unmerged paths
class UnmergedPathsError extends GitError {
  const UnmergedPathsError(super.message, {super.code = 'UnmergedPathsError'});
  
  @override
  String toString() => 'UnmergedPathsError: $message';
}