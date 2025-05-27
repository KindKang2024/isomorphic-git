String basename(String path) {
  final last = path.lastIndexOf('/') > path.lastIndexOf('\\')
      ? path.lastIndexOf('/')
      : path.lastIndexOf('\\');
  if (last > -1) {
    path = path.substring(last + 1);
  }
  return path;
}
