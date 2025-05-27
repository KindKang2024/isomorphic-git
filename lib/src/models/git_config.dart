import 'dart:convert';

// Helper function to parse boolean values from config
bool(dynamic val) {
  if (val is bool) {
    return val;
  }
  if (val is String) {
    String lowerVal = val.trim().toLowerCase();
    if (lowerVal == 'true' || lowerVal == 'yes' || lowerVal == 'on') return true;
    if (lowerVal == 'false' || lowerVal == 'no' || lowerVal == 'off') return false;
  }
  throw FormatException(
      "Expected 'true', 'false', 'yes', 'no', 'on', or 'off', but got $val");
}

// Helper function to parse numeric values from config (k, m, g suffixes)
num(dynamic val) {
  if (val is num) {
    return val.toInt();
  }
  if (val is String) {
    String lowerVal = val.toLowerCase();
    int n = int.tryParse(lowerVal.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (lowerVal.endsWith('k')) n *= 1024;
    if (lowerVal.endsWith('m')) n *= 1024 * 1024;
    if (lowerVal.endsWith('g')) n *= 1024 * 1024 * 1024;
    return n;
  }
  return 0; // Or throw error
}

final Map<String, Map<String, Function>> schema = {
  'core': {
    'filemode': bool,
    'bare': bool,
    'logallrefupdates': bool,
    'symlinks': bool,
    'ignorecase': bool,
    'bigfilethreshold': num, // Note: JS version has 'bigFileThreshold'
  },
  // Add other sections and their schemas as needed
};

class GitConfigEntry {
  final String line;
  final bool isSection;
  final String? section;
  final String? subsection;
  final String? name;
  final String? value;
  final String path; // Combined path like section.subsection.name or section.name

  GitConfigEntry({
    required this.line,
    required this.isSection,
    this.section,
    this.subsection,
    this.name,
    this.value,
    required this.path,
  });
}

class GitConfig {
  List<GitConfigEntry> _parsedConfig = [];

  GitConfig(String? text) {
    if (text == null || text.isEmpty) {
      _parsedConfig = [];
      return;
    }

    String? currentSection;
    String? currentSubsection;
    final lines = LineSplitter.split(text);

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('#') ||
          trimmedLine.startsWith(';')) {
        // Store comments/empty lines if needed for full reconstruction, or skip
        // For now, skipping them for parsing values, but they are part of original `line`
        // _parsedConfig.add(GitConfigEntry(line: line, isSection: false, path: ''));
        continue;
      }

      final sectionMatch = _SECTION_LINE_REGEX.firstMatch(trimmedLine);
      if (sectionMatch != null) {
        currentSection = sectionMatch.group(1)?.toLowerCase();
        currentSubsection = sectionMatch.group(2); // Keep original case for subsection as per git
        _parsedConfig.add(GitConfigEntry(
          line: line,
          isSection: true,
          section: currentSection,
          subsection: currentSubsection,
          path: _getPath(currentSection, currentSubsection, null),
        ));
      } else {
        final variableMatch = _VARIABLE_LINE_REGEX.firstMatch(trimmedLine);
        if (variableMatch != null && currentSection != null) {
          final name = variableMatch.group(1)?.toLowerCase();
          String rawValue = variableMatch.group(2) ?? 'true';
          final valueWithoutComments = _removeComments(rawValue);
          final valueWithoutQuotes = _removeQuotes(valueWithoutComments);

          _parsedConfig.add(GitConfigEntry(
            line: line,
            isSection: false,
            section: currentSection,
            subsection: currentSubsection,
            name: name,
            value: valueWithoutQuotes,
            path: _getPath(currentSection, currentSubsection, name),
          ));
        }
      }
    }
  }

  static final _SECTION_LINE_REGEX = RegExp(r'^\s*\[([A-Za-z0-9-.]+)(?: "(.*)")?\]\s*$');
  static final _VARIABLE_LINE_REGEX = RegExp(r'^\s*([A-Za-z][A-Za-z0-9-]*)(?:\s*=\s*(.*))?\s*$');
  static final _VARIABLE_VALUE_COMMENT_REGEX = RegExp(r'^(.*?)( *[#;].*)$');

  static String _removeComments(String rawValue) {
    final commentMatch = _VARIABLE_VALUE_COMMENT_REGEX.firstMatch(rawValue);
    if (commentMatch == null) {
      return rawValue.trim();
    }
    final valueWithoutComment = commentMatch.group(1)!.trim();
    final comment = commentMatch.group(2)!;
    // if odd number of quotes before and after comment => comment is escaped
    if (_hasOddNumberOfQuotes(valueWithoutComment) && _hasOddNumberOfQuotes(comment)) {
      return '$valueWithoutComment$comment'.trim();
    }
    return valueWithoutComment;
  }

  static bool _hasOddNumberOfQuotes(String text) {
    int count = 0;
    bool escaped = false;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\\') {
        escaped = !escaped;
      } else if (text[i] == '"' && !escaped) {
        count++;
        escaped = false;
      } else {
        escaped = false;
      }
    }
    return count % 2 != 0;
  }

  static String _removeQuotes(String text) {
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      // This is a simplified unquoting. Git's unquoting is more complex.
      // It handles escaped quotes inside, etc.
      // For a more robust solution, a proper parser for Git config values is needed.
      String inner = text.substring(1, text.length - 1);
      return inner.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
    }
    return text;
  }

  static String _getPath(String? section, String? subsection, String? name) {
    return [section?.toLowerCase(), subsection, name?.toLowerCase()]
        .where((s) => s != null && s.isNotEmpty)
        .join('.');
  }

  static ({String section, String? subsection, String? name, String path, String sectionPath, bool isSection}) _normalizePath(String path) {
    final pathSegments = path.split('.');
    final section = pathSegments.removeAt(0).toLowerCase();
    String? name;
    if (pathSegments.isNotEmpty) {
      name = pathSegments.removeLast().toLowerCase();
    }
    final subsection = pathSegments.isNotEmpty ? pathSegments.join('.') : null;

    return (
      section: section,
      subsection: subsection,
      name: name,
      path: _getPath(section, subsection, name),
      sectionPath: _getPath(section, subsection, null),
      isSection: name == null,
    );
  }

  static GitConfig from(String text) {
    return GitConfig(text);
  }

  Future<dynamic> get(String path, [bool getAll = false]) async {
    final normalizedPathInfo = _normalizePath(path);
    final targetPath = normalizedPathInfo.path;

    final allValues = _parsedConfig
        .where((config) => config.path == targetPath && config.value != null)
        .map((entry) {
          final sectionSchema = schema[entry.section!];
          final typeTransformer = sectionSchema?[entry.name!];
          return typeTransformer != null ? typeTransformer(entry.value) : entry.value;
        })
        .toList();

    if (getAll) {
      return allValues;
    }
    return allValues.isNotEmpty ? allValues.last : null;
  }

  Future<List<dynamic>> getAll(String path) async {
    var result = await get(path, true);
    return result as List<dynamic>;
  }

  Future<List<String?>> getSubsections(String section) async {
    final lowerSection = section.toLowerCase();
    return _parsedConfig
        .where((config) => config.isSection && config.section == lowerSection && config.subsection != null)
        .map((config) => config.subsection)
        .toSet() // Get unique subsections
        .toList();
  }

  Future<void> set(String path, dynamic value) async {
    final normalizedPathInfo = _normalizePath(path);
    if (normalizedPathInfo.name == null) {
      throw ArgumentError('Cannot set value for a section path, specify a variable name.');
    }

    final String section = normalizedPathInfo.section;
    final String? subsection = normalizedPathInfo.subsection;
    final String name = normalizedPathInfo.name!;
    final String targetPath = normalizedPathInfo.path;

    // Remove existing entries for this path
    _parsedConfig.removeWhere((entry) => entry.path == targetPath && !entry.isSection);

    // Find or create section header
    int sectionIndex = _parsedConfig.lastIndexWhere((entry) =>
        entry.isSection &&
        entry.section == section &&
        entry.subsection == subsection);

    String lineToInsert;
    if (value == null) { // Unset the variable
      // If value is null, we've already removed it. Nothing more to do unless we want to remove empty sections.
      return;
    } else if (value is bool) {
      lineToInsert = '$name = ${value ? 'true' : 'false'}';
    } else {
      lineToInsert = '$name = $value'; // May need quoting for strings with spaces/special chars
    }

    final newEntry = GitConfigEntry(
      line: lineToInsert, // This line is a bit simplified, doesn't include indentation
      isSection: false,
      section: section,
      subsection: subsection,
      name: name,
      value: value.toString(), // Store the string representation
      path: targetPath,
    );

    if (sectionIndex == -1) {
      // Section doesn't exist, create it
      String sectionHeaderLine = subsection != null ? '[$section "$subsection"]' : '[$section]';
      _parsedConfig.add(GitConfigEntry(
          line: sectionHeaderLine, isSection: true, section: section, subsection: subsection, path: _getPath(section, subsection, null)));
      _parsedConfig.add(newEntry);
    } else {
      _parsedConfig.insert(sectionIndex + 1, newEntry);
    }
  }

  @override
  String toString() {
    // Reconstruct the config file from _parsedConfig, trying to maintain original lines where possible
    // This is a simplified toString. A more robust one would handle comments, original spacing etc.
    final sb = StringBuffer();
    String? lastSection;
    String? lastSubsection;

    for (final entry in _parsedConfig) {
        if (entry.isSection) {
            if (entry.section != lastSection || entry.subsection != lastSubsection) {
                if (sb.isNotEmpty) sb.writeln(); // Add a newline before new section if not the first
                sb.writeln(entry.line); // Use original line for sections
                lastSection = entry.section;
                lastSubsection = entry.subsection;
            }
        } else if (entry.name != null && entry.value != null) {
            // For variables, prefer the reconstructed line from set, or original if not modified
            // This part needs more sophisticated tracking of original vs modified lines
            sb.writeln('  ${entry.name} = ${entry.value}'); // Simplified reconstruction
        }
    }
    return sb.toString();
  }
}