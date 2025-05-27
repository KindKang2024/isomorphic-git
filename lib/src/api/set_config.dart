import '../managers/git_config_manager.dart';
import '../models/file_system.dart';
import '../utils/assert_parameter.dart';
import '../utils/join.dart';

/// Write an entry to the git config files.
///
/// *Caveats:*
/// - Currently only the local `$GIT_DIR/config` file can be read or written. Support for global and system configs may be added later.
/// - The current parser does not support exotic features like `[include]` and `[includeIf]`.
///
/// [fs] - a file system implementation
/// [dir] - The [working tree](dir-vs-gitdir.md) directory path
/// [gitdir] - [required] The [git directory](dir-vs-gitdir.md) path
/// [path] - The key of the git config entry (e.g., 'user.name')
/// [value] - A value to store. Use `null` to delete a config entry.
/// [append] - If true, will append rather than replace (for multi-valued options).
///
/// Returns a [Future<void>] that resolves successfully when the operation is completed.
///
/// Example:
/// ```dart
/// // Write config value
/// await git.setConfig(
///   fs: fs,
///   dir: '/tutorial',
///   path: 'user.name',
///   value: 'Mr. Test',
/// );
///
/// // Delete a config entry
/// await git.setConfig(
///   fs: fs,
///   dir: '/tutorial',
///   path: 'user.name',
///   value: null, // Use null to delete
/// );
/// ```
Future<void> setConfig({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String path,
  dynamic value, // Can be String, bool, num, or null (for deletion)
  bool append = false,
}) async {
  final String effectiveGitdir = gitdir ?? join(dir, '.git');
  final fsModel = FileSystem(fs);

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('path', path);
    // `value` can be null for deletion, so no direct assertParameter for it here.

    final config = await GitConfigManager.get(
      fs: fsModel,
      gitdir: effectiveGitdir,
    );
    if (append) {
      // Dart's dynamic typing handles different value types naturally.
      // The `append` method in GitConfigManager should be designed to handle this.
      await config.append(path, value);
    } else {
      // `set` method should also handle various types, including null for deletion.
      await config.set(path, value);
    }
    await GitConfigManager.save(
      fs: fsModel,
      gitdir: effectiveGitdir,
      config: config,
    );
  } catch (e) {
    rethrow;
  }
}
