import '../commands/list_notes.dart' as commands;
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

class NoteEntry {
  final String target;
  final String note;

  NoteEntry({required this.target, required this.note});
}

/// List all the object notes
Future<List<NoteEntry>> listNotes({
  required FileSystem fs,
  String? dir,
  String? gitdir,
  String ref = 'refs/notes/commits',
  Map<String, dynamic> cache = const {},
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('ref', ref);

    var results = await commands.listNotes(
      fs: FileSystem(fs.client),
      cache: cache,
      gitdir: gitdir,
      ref: ref,
    );
    return results
        .map((e) => NoteEntry(target: e['target'], note: e['note']))
        .toList();
  } catch (err) {
    //TODO: err.caller = 'git.listNotes';
    rethrow;
  }
}
