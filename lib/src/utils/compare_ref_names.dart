int compareRefNames(String a, String b) {
  final _a = a.replaceAll(RegExp(r'\^\{\}\$'), '');
  final _b = b.replaceAll(RegExp(r'\^\{\}\$'), '');
  final tmp = -(_a.compareTo(_b) < 0 ? 1 : 0) | (_a.compareTo(_b) > 0 ? 1 : 0);
  if (tmp == 0) {
    return a.endsWith('^{}') ? 1 : -1;
  }
  return tmp;
}
