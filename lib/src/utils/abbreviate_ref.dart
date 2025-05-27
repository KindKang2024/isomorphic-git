// @see https://git-scm.com/docs/git-rev-parse.html#_specifying_revisions
final _abbreviateRx = RegExp(r'^refs/(heads/|tags/|remotes/)?(.*)');

String abbreviateRef(String ref) {
  final match = _abbreviateRx.firstMatch(ref);
  if (match != null) {
    String? group1 = match.group(1); // refs/(heads/|tags/|remotes/)
    String group2 = match.group(2)!; // (.*)

    if (group1 == 'remotes/' && group2.endsWith('/HEAD')) {
      return group2.substring(0, group2.length - 5);
    } else {
      return group2;
    }
  }
  return ref;
}