/// Git constants and enums
library;

/// Git object types
enum GitObjectType {
  blob('blob'),
  tree('tree'),
  commit('commit'),
  tag('tag');

  const GitObjectType(this.value);
  final String value;
}

/// File status constants
class GitStatus {
  static const int workdir = 0;
  static const int stage = 1;
  static const int tree = 2;
}

/// Git file modes
class GitFileMode {
  static const int file = 0o100644;
  static const int executable = 0o100755;
  static const int symlink = 0o120000;
  static const int tree = 0o040000;
  static const int gitlink = 0o160000;
}

/// Default Git configuration
class GitDefaults {
  static const String defaultBranch = 'main';
  static const String gitDir = '.git';
  static const String objectsDir = 'objects';
  static const String refsDir = 'refs';
  static const String headsDir = 'refs/heads';
  static const String tagsDir = 'refs/tags';
  static const String remotesDir = 'refs/remotes';
}