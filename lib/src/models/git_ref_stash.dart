class GitRefStash {
  static String get timezoneOffsetForRefLogEntry {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final offsetHours = (offsetMinutes / 60).abs().floor();
    final offsetMinutesFormatted = (offsetMinutes % 60)
        .abs()
        .toString()
        .padLeft(2, '0');
    final sign = offsetMinutes > 0
        ? '-'
        : '+'; // Note: Dart's offset is positive for UTC+X, JS is negative
    return '$sign${offsetHours.toString().padLeft(2, '0')}$offsetMinutesFormatted';
  }

  static String createStashReflogEntry(
    Map<String, String> author,
    String stashCommit,
    String message,
  ) {
    final nameNoSpace = (author['name'] ?? '').replaceAll(RegExp(r'\s'), '');
    final email = author['email'] ?? '';
    const z40 = '0000000000000000000000000000000000000000'; // hard code for now
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final timezoneOffset = timezoneOffsetForRefLogEntry;
    // Format: <old-oid> <new-oid> <committer> <timestamp> <timezone>\t<message>\n
    // The original JS code had a slight deviation in the reflog format for stash.
    // Standard reflog: <old-oid> <new-oid> <author> <timestamp> <tz>\t<message>
    // Stash reflog in JS: <z40> <stashCommit> <nameNoSpace> <email> <timestamp> <tz>\t<message>
    // Let's stick to the JS version for direct porting, but be aware it might differ from standard git reflog.
    return '$z40 $stashCommit $nameNoSpace <$email> $timestamp $timezoneOffset\t$message\n';
  }

  static List<String> getStashReflogEntry(
    String reflogString, {
    bool parsed = false,
  }) {
    final reflogLines = reflogString.split('\n');
    final entries = reflogLines
        .where((l) => l.isNotEmpty)
        .toList()
        .reversed
        .toList() // Convert to list before map for indexing
        .asMap()
        .entries
        .map((entry) {
          final idx = entry.key;
          final line = entry.value;
          return parsed ? 'stash@{$idx}: ${line.split('\t')[1]}' : line;
        })
        .toList();
    return entries;
  }
}
