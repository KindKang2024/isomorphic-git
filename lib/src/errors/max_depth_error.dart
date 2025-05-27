class MaxDepthError extends Error {
  static const String code = 'MaxDepthError';
  final int depth;

  MaxDepthError(this.depth) : super();

  @override
  String toString() {
    return 'MaxDepthError: Maximum search depth of $depth exceeded.';
  }
}
