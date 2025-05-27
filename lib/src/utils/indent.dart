String indent(String str) {
  return str.trim().split('\n').map((x) => ' ' + x).join('\n') + '\n';
}
