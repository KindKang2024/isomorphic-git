bool compareStats(
  dynamic entry,
  dynamic stats, {
  bool filemode = true,
  bool trustino = true,
}) {
  final e = normalizeStats(entry);
  final s = normalizeStats(stats);
  final staleness =
      (filemode && e['mode'] != s['mode']) ||
      e['mtimeSeconds'] != s['mtimeSeconds'] ||
      e['ctimeSeconds'] != s['ctimeSeconds'] ||
      e['uid'] != s['uid'] ||
      e['gid'] != s['gid'] ||
      (trustino && e['ino'] != s['ino']) ||
      e['size'] != s['size'];
  return staleness;
}
