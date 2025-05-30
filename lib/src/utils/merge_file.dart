class MergeFileResult {
  final bool cleanMerge;
  final String mergedText;

  MergeFileResult({required this.cleanMerge, required this.mergedText});
}

MergeFileResult mergeFile({
  required List<String> branches,
  required List<String> contents,
}) {
  final ourName = branches[1];
  final theirName = branches[2];

  final baseContent = contents[0];
  final ourContent = contents[1];
  final theirContent = contents[2];

  // Dart's string split behaves differently from JS's match with a global regex.
  // JS match with /gm on /^.*(\r?\n|$)/gm will include the line breaks.
  // Dart's split by RegExp('\r?\n') will consume them.
  // To replicate, we can add them back or use a different approach.
  // For simplicity, this translation assumes lines are split by newline
  // and newlines are re-added. A more robust solution might be needed.
  final lineBreakPattern = RegExp(r'^.*(?:\r?\n|$)', multiLine: true);

  List<String> splitToLines(String content) {
    return lineBreakPattern
        .allMatches(content)
        .map((m) => m.group(0)!)
        .toList();
  }

  final ours = splitToLines(ourContent);
  final base = splitToLines(baseContent);
  final theirs = splitToLines(theirContent);

  // Placeholder for diff3Merge logic.
  // This is a complex part and requires a proper 3-way merge algorithm.
  // The 'diff_match_patch' library provides 2-way diff.
  // A 3-way merge typically involves:
  // 1. Diff base vs ours
  // 2. Diff base vs theirs
  // 3. Merge the two diffs.
  // For now, we'll simulate a result structure similar to the JS diff3 library.
  // This will need to be replaced with actual 3-way merge logic.

  // Simulated diff3.Result (replace with actual library call)
  // TODO: Implement or find a Dart library for 3-way merge (diff3)
  // For now, this is a placeholder structure.
  // The actual diff3Merge function in JS returns an array of objects,
  // each object having either an 'ok' property (array of lines)
  // or a 'conflict' property (object with 'a', 'o', 'b' arrays of lines).
  // Since we don't have 'o' (original base lines in conflict) in the JS output processing,
  // we simplify the conflict part here.
  List<Map<String, dynamic>> result = [];

  // Simplified placeholder: If contents are different, assume a conflict for demonstration
  if (ourContent != baseContent || theirContent != baseContent) {
    if (ourContent != theirContent) {
      // A simplistic conflict
      result.add({
        'conflict': {
          'a': ours, // Our lines involved in conflict
          'b': theirs, // Their lines involved in conflict
        },
      });
    } else {
      // No conflict, ours and theirs are the same but different from base
      result.add({'ok': ours});
    }
  } else {
    // All contents are the same
    result.add({'ok': base});
  }

  const markerSize = 7;
  var mergedText = '';
  var cleanMerge = true;

  for (final item in result) {
    if (item.containsKey('ok')) {
      mergedText += (item['ok'] as List<String>).join('');
    }
    if (item.containsKey('conflict')) {
      cleanMerge = false;
      final conflict = item['conflict'] as Map<String, List<String>>;
      mergedText += '${'<' * markerSize} $ourName\n';
      mergedText += conflict['a']!.join('');
      mergedText += '${'=' * markerSize}\n';
      // The original JS used item.conflict.b from diff3.
      // The diff3 library's conflict object has 'o' (base), 'a' (ours), 'b' (theirs).
      // Here, we are simulating with what's available.
      mergedText += conflict['b']!.join('');
      mergedText += '${'>' * markerSize} $theirName\n';
    }
  }

  return MergeFileResult(cleanMerge: cleanMerge, mergedText: mergedText);
}

void main() {
  // Example Usage:
  final branches = ['base', 'ours', 'theirs'];
  final contents = [
    'Line 1\nLine 2 common\nLine 3 base\n', // base
    'Line 1\nLine 2 common\nLine 3 ours\nLine 4 ours\n', // ours
    'Line 1\nLine 2 common\nLine 3 theirs\nLine 4 theirs\n', // theirs
  ];

  final result = mergeFile(branches: branches, contents: contents);
  print('Clean Merge: ${result.cleanMerge}');
  print('Merged Text:\n${result.mergedText}');

  final contentsNoConflict = [
    'Line 1\nLine 2\n', // base
    'Line 1\nLine 2\nLine 3 added\n', // ours
    'Line 1\nLine 2\nLine 3 added\n', // theirs
  ];
  final resultNoConflict = mergeFile(
    branches: branches,
    contents: contentsNoConflict,
  );
  print('Clean Merge (No Conflict): ${resultNoConflict.cleanMerge}');
  print('Merged Text (No Conflict):\n${resultNoConflict.mergedText}');
}
