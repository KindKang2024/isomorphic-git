class NoRefspecError extends Error {
  static const String code = 'NoRefspecError';
  final String remote;

  NoRefspecError(this.remote) : super();

  @override
  String toString() {
    return '''NoRefspecError: Could not find a fetch refspec for remote "$remote". Make sure the config file has an entry like the following:
[remote "$remote"]
\tfetch = +refs/heads/*:refs/remotes/origin/*
''';
  }
}
