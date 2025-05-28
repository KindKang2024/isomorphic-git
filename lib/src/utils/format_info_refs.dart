class ServerRef {
  String ref;
  String oid;
  String? target;
  String? peeled;

  ServerRef({required this.ref, required this.oid, this.target, this.peeled});

  @override
  String toString() {
    return 'ServerRef(ref: $ref, oid: $oid, target: $target, peeled: $peeled)';
  }
}

List<ServerRef> formatInfoRefs({
  required Map<String, String> remoteRefs,
  required Map<String, String> remoteSymrefs,
  String? prefix,
  required bool symrefs,
  required bool peelTags,
}) {
  final List<ServerRef> refs = [];
  for (final entry in remoteRefs.entries) {
    final key = entry.key;
    final value = entry.value;

    if (prefix != null && !key.startsWith(prefix)) continue;

    if (key.endsWith('^{}')) {
      if (peelTags) {
        final _key = key.replaceAll('^{}', '');
        // Peeled tags are almost always listed immediately after the original tag
        ServerRef? r;
        if (refs.isNotEmpty && refs.last.ref == _key) {
          r = refs.last;
        } else {
          try {
            r = refs.firstWhere((x) => x.ref == _key);
          } catch (e) {
            // Dart's firstWhere throws if not found, JS find returns undefined
            r = null;
          }
        }

        if (r == null) {
          throw Exception('I did not expect this to happen');
        }
        r.peeled = value;
      }
      continue;
    }

    final ref = ServerRef(ref: key, oid: value);
    if (symrefs) {
      if (remoteSymrefs.containsKey(key)) {
        ref.target = remoteSymrefs[key];
      }
    }
    refs.add(ref);
  }
  return refs;
}
