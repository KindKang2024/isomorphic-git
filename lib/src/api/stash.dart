import '../commands/stash.dart';
import '../errors/invalid_ref_name_error.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

enum StashOpType { push, pop, apply, drop, list, clear }

String _stashOpTypeToString(StashOpType op) => op.toString().split('.').last;
StashOpType _stringToStashOpType(String op) {
  return StashOpType.values.firstWhere(
    (e) => _stashOpTypeToString(e) == op,
    orElse: () => throw ArgumentError('Invalid StashOpType string'),
  );
}

/// Stash API, supports {'push' | 'pop' | 'apply' | 'drop' | 'list' | 'clear'} StashOp
/// _note_,
/// - all stash operations are done on tracked files only with loose objects, no packed objects
/// - when op === 'push', both working directory and index (staged) changes will be stashed, tracked files only
/// - when op === 'push', message is optional, and only applicable when op === 'push'
/// - when op === 'apply | pop', the stashed changes will overwrite the working directory, no abort when conflicts
///
/// [fs] - [required] a file system client
/// [dir] - [required] The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [optional] The [git directory](dir-vs-gitdir.md) path
/// [op] - [optional] name of stash operation, default to 'push'
/// [message] - [optional] message to be used for the stash entry, only applicable when op === 'push'
/// [refIdx] - [optional - Number] stash ref index of entry, only applicable when op === ['apply' | 'drop' | 'pop'], refIdx >= 0 and < num of stash pushed
/// Returns a [Future<dynamic>] (String for list, void for others) that resolves successfully when stash operations are complete.
Future<dynamic> stash({
  required dynamic fs,
  required String dir,
  String? gitdir,
  StashOpType op = StashOpType.push,
  String message = '',
  int refIdx = 0,
}) async {
  final effectiveGitdir = gitdir ?? join(dir, '.git');

  assertParameter('fs', fs);
  assertParameter('dir', dir);
  assertParameter('gitdir', effectiveGitdir);
  // op is enum, no direct assert needed if type system is used correctly

  final fsModel = FileSystem(fs);

  // Ensure necessary directories exist (ported from JS)
  var folders = ['refs', 'logs', 'logs/refs'];
  for (var f in folders) {
    var folderPath = join(effectiveGitdir, f);
    if (!(await fsModel.exists(folderPath))) {
      await fsModel.mkdir(folderPath);
    }
  }

  try {
    switch (op) {
      case StashOpType.push:
        return await stashPush(
          fs: fsModel,
          dir: dir,
          gitdir: effectiveGitdir,
          message: message,
        );
      case StashOpType.apply:
        if (refIdx < 0)
          throw InvalidRefNameError(
            'stash@$refIdx',
            'number that is in range of [0, num of stash pushed]',
          );
        return await stashApply(
          fs: fsModel,
          dir: dir,
          gitdir: effectiveGitdir,
          refIdx: refIdx,
        );
      case StashOpType.drop:
        if (refIdx < 0)
          throw InvalidRefNameError(
            'stash@$refIdx',
            'number that is in range of [0, num of stash pushed]',
          );
        return await stashDrop(
          fs: fsModel,
          dir: dir,
          gitdir: effectiveGitdir,
          refIdx: refIdx,
        );
      case StashOpType.list:
        return await stashList(fs: fsModel, dir: dir, gitdir: effectiveGitdir);
      case StashOpType.clear:
        return await stashClear(fs: fsModel, dir: dir, gitdir: effectiveGitdir);
      case StashOpType.pop:
        if (refIdx < 0)
          throw InvalidRefNameError(
            'stash@$refIdx',
            'number that is in range of [0, num of stash pushed]',
          );
        return await stashPop(
          fs: fsModel,
          dir: dir,
          gitdir: effectiveGitdir,
          refIdx: refIdx,
        );
      default:
        // This case should not be reached if StashOpType is used correctly.
        throw UnimplementedError('Stash operation $op not implemented');
    }
  } catch (e) {
    rethrow;
  }
}
