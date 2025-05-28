import './base_error.dart';

class CommitNotFetchedError extends BaseError {
  final String ref;
  final String oid;

  CommitNotFetchedError(this.ref, this.oid)
      : super(message:
            'Failed to checkout "$ref" because commit $oid is not available locally. Do a git fetch to make the branch available locally.') {
    super.code = "CommitNotFetchedError";
    super.data = {'ref': ref, 'oid': oid};
  }
}