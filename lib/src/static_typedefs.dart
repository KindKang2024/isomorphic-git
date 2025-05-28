
// Git type definitions for Dart

// Placeholder for an assumed GitAuthor class, adjust as necessary
class GitAuthor {
  String name;
  String email;
  int timestamp;
  int timezoneOffset;
  GitAuthor({required this.name, required this.email, required this.timestamp, required this.timezoneOffset});
}

// Placeholder for an assumed GitCommitter class, adjust as necessary
class GitCommitter {
  String name;
  String email;
  int timestamp;
  int timezoneOffset;
  GitCommitter({required this.name, required this.email, required this.timestamp, required this.timezoneOffset});
}

/// A git commit object
class CommitObject {
  String message;
  String tree;
  List<String> parent;
  GitAuthor author;
  GitCommitter committer;
  String? gpgsig;
  
  CommitObject({
    required this.message,
    required this.tree,
    required this.parent,
    required this.author,
    required this.committer,
    this.gpgsig,
  });
}

/// An entry from a git tree object
class TreeEntry {
  String mode;
  String path;
  String oid;
  String type; // 'commit', 'blob', 'tree'
  
  TreeEntry({
    required this.mode,
    required this.path,
    required this.oid,
    required this.type,
  });
}

/// A git tree object - represents a directory snapshot
typedef TreeObject = List<TreeEntry>;

/// A git annotated tag object
class TagObject {
  String object;
  String type; // 'blob', 'tree', 'commit', 'tag'
  String tag;
  GitAuthor tagger;
  String message;
  String? gpgsig;
  
  TagObject({
    required this.object,
    required this.type,
    required this.tag,
    required this.tagger,
    required this.message,
    this.gpgsig,
  });
}

/// Result of reading a commit
class ReadCommitResult {
  String oid;
  CommitObject commit;
  String payload;
  
  ReadCommitResult({
    required this.oid,
    required this.commit,
    required this.payload,
  });
}

/// Server ref information
class ServerRef {
  String ref;
  String oid;
  String? target;
  String? peeled;
  
  ServerRef({
    required this.ref,
    required this.oid,
    this.target,
    this.peeled,
  });
}

/// Normalized subset of filesystem stat data
class Stat {
  int ctimeSeconds;
  int ctimeNanoseconds;
  int mtimeSeconds;
  int mtimeNanoseconds;
  int dev;
  int ino;
  int mode;
  int uid;
  int gid;
  int size;
  
  Stat({
    required this.ctimeSeconds,
    required this.ctimeNanoseconds,
    required this.mtimeSeconds,
    required this.mtimeNanoseconds,
    required this.dev,
    required this.ino,
    required this.mode,
    required this.uid,
    required this.gid,
    required this.size,
  });
}