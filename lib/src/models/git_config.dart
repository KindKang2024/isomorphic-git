import 'dart:convert';

// Helper function to parse boolean values from config
bool parseBool(dynamic val) {
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
int parseNum(dynamic val) {
  if (val is num) {
    return val.toInt();
  }
  if (val is String) {
    String lowerVal = val.toLowerCase();
    int n = int.tryParse(lowerVal.replaceAll(RegExp(r'[kmg]'), '')) ?? 0;
    if (lowerVal.endsWith('k')) n *= 1024;
    if (lowerVal.endsWith('m')) n *= 1024 * 1024;
    if (lowerVal.endsWith('g')) n *= 1024 * 1024 * 1024;
    return n;
  }
  return 0;
}

final Map<String, Map<String, Function>> schema = {
  'core': {
    'filemode': parseBool,
    'bare': parseBool,
    'logallrefupdates': parseBool,
    'symlinks': parseBool,
    'ignorecase': parseBool,
    'bigfilethreshold': parseNum,
  },
};

class GitConfigEntry {
  final String line;
  final bool isSection;
  final String? section;
  final String? subsection;
  final String? name;
  final String? value;
  final String path;
  final bool modified;

  GitConfigEntry({
    required this.line,
    required this.isSection,
    this.section,
    this.subsection,
    this.name,
    this.value,
    required this.path,
    this.modified = false,
  });

  GitConfigEntry copyWith({
    String? line,
    bool? isSection,
    String? section,
    String? subsection,
    String? name,
    String? value,
    String? path,
    bool? modified,
  }) {
    return GitConfigEntry(
      line: line ?? this.line,
      isSection: isSection ?? this.isSection,
      section: section ?? this.section,
      subsection: subsection ?? this.subsection,
      name: name ?? this.name,
      value: value ?? this.value,
      path: path ?? this.path,
      modified: modified ?? this.modified,
    );
  }
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
      String? name;
      String? value;
      
      final trimmedLine = line.trim();
      final extractedSection = _extractSectionLine(trimmedLine);
      final isSection = extractedSection != null;
      
      if (isSection) {
        currentSection = extractedSection![0];
        currentSubsection = extractedSection[1];
      } else {
        final extractedVariable = _extractVariableLine(trimmedLine);
        final isVariable = extractedVariable != null;
        if (isVariable) {
          name = extractedVariable![0];
          value = extractedVariable[1];
        }
      }

      final path = _getPath(currentSection, currentSubsection, name);
      _parsedConfig.add(GitConfigEntry(
        line: line,
        isSection: isSection,
        section: currentSection,
        subsection: currentSubsection,
        name: name,
        value: value,
        path: path,
      ));
    }
  }

  static final _SECTION_LINE_REGEX = RegExp(r'^\[([A-Za-z0-9-.]+)(?: "(.*)")?\]$');
  static final _VARIABLE_LINE_REGEX = RegExp(r'^([A-Za-z][A-Za-z-]*)(?: *= *(.*))?$');
  static final _VARIABLE_VALUE_COMMENT_REGEX = RegExp(r'^(.*?)( *[#;].*)$');
  static final _SECTION_REGEX = RegExp(r'^[A-Za-z0-9-.]+$');
  static final _VARIABLE_NAME_REGEX = RegExp(r'^[A-Za-z][A-Za-z-]*$');

  static List<String>? _extractSectionLine(String line) {
    final matches = _SECTION_LINE_REGEX.firstMatch(line);
    if (matches != null) {
      return [matches.group(1)!, matches.group(2) ?? ''];
    }
    return null;
  }

  static List<String>? _extractVariableLine(String line) {
    final matches = _VARIABLE_LINE_REGEX.firstMatch(line);
    if (matches != null) {
      final name = matches.group(1)!;
      final rawValue = matches.group(2) ?? 'true';
      final valueWithoutComments = _removeComments(rawValue);
      final valueWithoutQuotes = _removeQuotes(valueWithoutComments);
      return [name, valueWithoutQuotes];
    }
    return null;
  }

  static String _removeComments(String rawValue) {
    final commentMatch = _VARIABLE_VALUE_COMMENT_REGEX.firstMatch(rawValue);
    if (commentMatch == null) {
      return rawValue;
    }
    final valueWithoutComment = commentMatch.group(1)!;
    final comment = commentMatch.group(2)!;
    // if odd number of quotes before and after comment => comment is escaped
    if (_hasOddNumberOfQuotes(valueWithoutComment) && _hasOddNumberOfQuotes(comment)) {
      return '$valueWithoutComment$comment';
    }
    return valueWithoutComment;
  }

  static bool _hasOddNumberOfQuotes(String text) {
    final matches = RegExp(r'(?:^|[^\\])"').allMatches(text);
    return matches.length % 2 != 0;
  }

  static String _removeQuotes(String text) {
    final chars = text.split('');
    final result = StringBuffer();
    
    for (int i = 0; i < chars.length; i++) {
      final c = chars[i];
      final isQuote = c == '"' && (i == 0 || chars[i - 1] != '\\');
      final isEscapeForQuote = c == '\\' && i + 1 < chars.length && chars[i + 1] == '"';
      
      if (!isQuote && !isEscapeForQuote) {
        result.write(c);
      }
    }
    
    return result.toString();
  }

  static String _getPath(String? section, String? subsection, String? name) {
    return [section?.toLowerCase(), subsection, name?.toLowerCase()]
        .where((s) => s != null && s.isNotEmpty)
        .join('.');
  }

  static ({String section, String? subsection, String? name, String path, String sectionPath, bool isSection}) _normalizePath(String path) {
    final pathSegments = path.split('.');
    final section = pathSegments.removeAt(0);
    String? name;
    if (pathSegments.isNotEmpty) {
      name = pathSegments.removeLast();
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

  static int _findLastIndex<T>(List<T> list, bool Function(T) test) {
    for (int i = list.length - 1; i >= 0; i--) {
      if (test(list[i])) {
        return i;
      }
    }
    return -1;
  }

  static GitConfig from(String text) {
    return GitConfig(text);
  }

  Future<dynamic> get(String path, [bool getAll = false]) async {
    final normalizedPath = _normalizePath(path).path;
    final allValues = _parsedConfig
        .where((config) => config.path == normalizedPath && config.value != null)
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

  Future<List<dynamic>> getall(String path) async {
    return await get(path, true) as List<dynamic>;
  }

  Future<List<String?>> getSubsections(String section) async {
    return _parsedConfig
        .where((config) => config.isSection && config.section == section && config.subsection != null)
        .map((config) => config.subsection)
        .toSet()
        .toList();
  }

  Future<void> deleteSection(String section, [String? subsection]) async {
    _parsedConfig.removeWhere((config) =>
        config.section == section && config.subsection == subsection);
  }

  Future<void> append(String path, dynamic value) async {
    return set(path, value, true);
  }

  Future<void> set(String path, dynamic value, [bool append = false]) async {
    final normalizedPathInfo = _normalizePath(path);
    final section = normalizedPathInfo.section;
    final subsection = normalizedPathInfo.subsection;
    final name = normalizedPathInfo.name;
    final normalizedPath = normalizedPathInfo.path;
    final sectionPath = normalizedPathInfo.sectionPath;
    final isSection = normalizedPathInfo.isSection;

    final configIndex = _findLastIndex(
      _parsedConfig,
      (config) => config.path == normalizedPath,
    );

    if (value == null) {
      if (configIndex != -1) {
        _parsedConfig.removeAt(configIndex);
      }
    } else {
      if (configIndex != -1) {
        final config = _parsedConfig[configIndex];
        final modifiedConfig = config.copyWith(
          name: name,
          value: value.toString(),
          modified: true,
        );
        if (append) {
          _parsedConfig.insert(configIndex + 1, modifiedConfig);
        } else {
          _parsedConfig[configIndex] = modifiedConfig;
        }
      } else {
        final sectionIndex = _parsedConfig.indexWhere(
          (config) => config.path == sectionPath,
        );
        final newConfig = GitConfigEntry(
          line: '',
          isSection: false,
          section: section,
          subsection: subsection,
          name: name,
          value: value.toString(),
          modified: true,
          path: normalizedPath,
        );
        
        if (_SECTION_REGEX.hasMatch(section) && name != null && _VARIABLE_NAME_REGEX.hasMatch(name)) {
          if (sectionIndex >= 0) {
            _parsedConfig.insert(sectionIndex + 1, newConfig);
          } else {
            final newSection = GitConfigEntry(
              line: '',
              isSection: true,
              section: section,
              subsection: subsection,
              modified: true,
              path: sectionPath,
            );
            _parsedConfig.addAll([newSection, newConfig]);
          }
        }
      }
    }
  }

  @override
  String toString() {
    return _parsedConfig
        .map((entry) {
          if (!entry.modified) {
            return entry.line;
          }
          if (entry.name != null && entry.value != null) {
            if (entry.value!.contains(RegExp(r'[#;]'))) {
              return '\t${entry.name} = "${entry.value}"';
            }
            return '\t${entry.name} = ${entry.value}';
          }
          if (entry.subsection != null) {
            return '[${entry.section} "${entry.subsection}"]';
          }
          return '[${entry.section}]';
        })
        .join('\n');
  }
}