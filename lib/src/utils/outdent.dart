String outdent(String str) {
  return str
      .split('\n')
      .map((x) => x.replaceFirst(RegExp(r'^ '), ''))
      .join('\n');
}
