String dirname(String path) {
  final last = path.lastIndexOf('/') > path.lastIndexOf('\\')
      ? path.lastIndexOf('/')
      : path.lastIndexOf('\\');
  if (last == -1) return '.';
  if (last == 0) return '/';
  return path.substring(0, last);
}
