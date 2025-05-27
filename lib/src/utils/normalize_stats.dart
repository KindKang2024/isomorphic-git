import '../utils/normalize_mode.dart';

const int MAX_UINT32 = 0x100000000;

List<int> secondsNanoseconds(
  int? givenSeconds,
  int? givenNanoseconds,
  int? milliseconds,
  DateTime? date,
) {
  if (givenSeconds != null && givenNanoseconds != null) {
    return [givenSeconds, givenNanoseconds];
  }
  if (milliseconds == null && date != null) {
    milliseconds = date.millisecondsSinceEpoch;
  }
  final seconds = (milliseconds ?? 0) ~/ 1000;
  final nanoseconds = ((milliseconds ?? 0) - seconds * 1000) * 1000000;
  return [seconds, nanoseconds];
}

Map<String, dynamic> normalizeStats(dynamic e) {
  final ctime = secondsNanoseconds(
    e.ctimeSeconds,
    e.ctimeNanoseconds,
    e.ctimeMs,
    e.ctime,
  );
  final mtime = secondsNanoseconds(
    e.mtimeSeconds,
    e.mtimeNanoseconds,
    e.mtimeMs,
    e.mtime,
  );

  return {
    'ctimeSeconds': ctime[0] % MAX_UINT32,
    'ctimeNanoseconds': ctime[1] % MAX_UINT32,
    'mtimeSeconds': mtime[0] % MAX_UINT32,
    'mtimeNanoseconds': mtime[1] % MAX_UINT32,
    'dev': e.dev % MAX_UINT32,
    'ino': e.ino % MAX_UINT32,
    'mode': normalizeMode(e.mode % MAX_UINT32),
    'uid': e.uid % MAX_UINT32,
    'gid': e.gid % MAX_UINT32,
    'size': (e.size > -1 ? e.size % MAX_UINT32 : 0),
  };
}
