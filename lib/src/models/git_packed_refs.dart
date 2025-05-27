import 'dart:collection'; // For HashMap

class ParsedRefEntry {
  final String line;
  final bool isComment;
  final String? ref;
  final String? oid;
  final String? peeled;

  ParsedRefEntry({
    required this.line,
    this.isComment = false,
    this.ref,
    this.oid,
    this.peeled,
  });
}

class GitPackedRefs {
  Map<String, String> refs = HashMap<String, String>();
  List<ParsedRefEntry> parsedConfig = [];

  GitPackedRefs(String? text) {
    if (text != null && text.trim().isNotEmpty) {
      String? currentKey;
      parsedConfig = text
          .trim()
          .split('\n')
          .map((line) {
            if (line.trim().startsWith('#')) {
              return ParsedRefEntry(line: line, isComment: true);
            }
            final i = line.indexOf(' ');
            if (i == -1) {
              // Invalid line format, treat as comment or error
              return ParsedRefEntry(line: line, isComment: true); 
            }

            if (line.startsWith('^')) {
              final value = line.substring(1);
              if (currentKey != null) {
                refs[currentKey + '^{}'] = value;
                return ParsedRefEntry(line: line, ref: currentKey, peeled: value);
              } else {
                 // Orphaned peeled ref, treat as comment or error
                return ParsedRefEntry(line: line, isComment: true);
              }
            } else {
              final oid = line.substring(0, i);
              currentKey = line.substring(i + 1);
              refs[currentKey!] = oid;
              return ParsedRefEntry(line: line, ref: currentKey, oid: oid);
            }
          })
          .toList();
    }
  }

  static GitPackedRefs from(String? text) {
    return GitPackedRefs(text);
  }

  void delete(String ref) {
    parsedConfig.removeWhere((entry) => entry.ref == ref);
    refs.remove(ref);
    refs.remove(ref + '^{}'); // Also remove potential peeled ref
  }

  @override
  String toString() {
    return parsedConfig.map((entry) => entry.line).join('\n') + '\n';
  }
}