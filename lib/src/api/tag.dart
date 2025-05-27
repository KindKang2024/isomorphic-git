import 'dart:async';

import '../errors/already_exists_error.dart';
import '../errors/missing_parameter_error.dart';
import '../managers/git_ref_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

typedef FsClient = dynamic; // Placeholder for FsClient type

Future<void> tag({
  required FsClient fs,
  String? dir,
  String? gitdir,
  required String ref,
  String? object,
  bool force = false,
}) async {
  try {
    assertParameter('fs', fs);
    gitdir ??= join(dir, '.git');
    assertParameter('gitdir', gitdir);
    assertParameter('ref', ref);

    final fsModel = FileSystem(fs);

    if (ref == null) {
      // Dart null safety handles this, but to be explicit like the JS version:
      throw MissingParameterError('ref');
    }

    var qualifiedRef = ref.startsWith('refs/tags/') ? ref : 'refs/tags/$ref';

    // Resolve passed object
    final value = await GitRefManager.resolve(
      fs: fsModel,
      gitdir: gitdir,
      ref: object ?? 'HEAD',
    );

    if (!force &&
        (await GitRefManager.exists(
          fs: fsModel,
          gitdir: gitdir,
          ref: qualifiedRef,
        ))) {
      throw AlreadyExistsError('tag', qualifiedRef);
    }

    await GitRefManager.writeRef(
      fs: fsModel,
      gitdir: gitdir,
      ref: qualifiedRef,
      value: value,
    );
  } catch (err) {
    // err.caller = 'git.tag'; // Dynamic property assignment not typical in Dart
    rethrow;
  }
}
