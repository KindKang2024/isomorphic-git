String normalizeNewlines(String str) {
  // remove all <CR>
  str = str.replaceAll('\r', '');
  // no extra newlines up front
  str = str.replaceAll(RegExp(r'^\n+'), '');
  // and a single newline at the end
  str = str.replaceAll(RegExp(r'\n+$'), '') + '\n';
  return str;
}
