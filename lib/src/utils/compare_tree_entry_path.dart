int compareTreeEntryPath(dynamic a, dynamic b) {
  String appendSlashIfDir(dynamic entry) {
    return entry['mode'] == '040000' ? '${entry['path']}/' : entry['path'];
  }

  return compareStrings(appendSlashIfDir(a), appendSlashIfDir(b));
}
