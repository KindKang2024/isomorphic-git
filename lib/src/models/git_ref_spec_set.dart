import './git_ref_spec.dart';

class GitRefSpecSet {
  List<GitRefSpec> rules;

  GitRefSpecSet([List<GitRefSpec>? rules]) : rules = rules ?? [];

  static GitRefSpecSet from(List<String> refspecs) {
    final rules = <GitRefSpec>[];
    for (final refspec in refspecs) {
      rules.add(GitRefSpec.from(refspec)); // might throw
    }
    return GitRefSpecSet(rules);
  }

  void add(String refspec) {
    final rule = GitRefSpec.from(refspec); // might throw
    rules.add(rule);
  }

  List<List<String>> translate(List<String> remoteRefs) {
    final result = <List<String>>[];
    for (final rule in rules) {
      for (final remoteRef in remoteRefs) {
        final localRef = rule.translate(remoteRef);
        if (localRef != null) {
          result.add([remoteRef, localRef]);
        }
      }
    }
    return result;
  }

  String? translateOne(String remoteRef) {
    String? result;
    for (final rule in rules) {
      final localRef = rule.translate(remoteRef);
      if (localRef != null) {
        result = localRef; // Takes the last match, consistent with JS
      }
    }
    return result;
  }

  List<String> localNamespaces() {
    return rules
        .where((rule) => rule.matchPrefix)
        .map((rule) => rule.localPath.endsWith('/') ? rule.localPath.substring(0, rule.localPath.length -1) : rule.localPath)
        .toList();
  }
}