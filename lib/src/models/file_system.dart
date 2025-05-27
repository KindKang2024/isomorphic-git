import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:path/path.dart' as p;

/// A class providing file system operations, similar to the JavaScript FileSystem class.
/// It uses Dart's `dart:io` for its operations.
class FileSystem {
  /// Checks if a file or directory exists at the given [filepath].
  /// Returns `true` if it exists, `false` otherwise.
  Future<bool> exists(String filepath) async {
    try {
      return await FileSystemEntity.type(filepath) != FileSystemEntityType.notFound;
    } catch (e) {
      // In case of other errors (e.g., permission issues), 
      // depending on desired behavior, you might want to rethrow or log.
      // For now, mimicking the JS behavior of returning false for common errors.
      if (e is FileSystemException && 
          (e.osError?.errorCode == 2 /* ENOENT */ || e.osError?.errorCode == 20 /* ENOTDIR */)) {
        return false;
      }
      // print('Unhandled error in FileSystem.exists: $e');
      // For strictness, one might rethrow or handle specific errors differently.
      return false; // Defaulting to false for other FS errors for now
    }
  }

  /// Reads the content of a file at [filepath].
  ///
  /// Returns `Uint8List` containing the file data, or `null` if the file
  /// cannot be read (e.g., does not exist).
  /// If [autocrlf] is true, CRLF line endings will be converted to LF.
  Future<Uint8List?> read(String filepath, {bool autocrlf = false}) async {
    try {
      final file = File(filepath);
      if (!await file.exists()) {
        return null;
      }
      Uint8List buffer = await file.readAsBytes();

      if (autocrlf) {
        try {
          // Attempt to decode as UTF-8. If it fails, it's likely a binary file.
          String content = utf8.decode(buffer, allowMalformed: false);
          content = content.replaceAll('\r\n', '\n');
          buffer = utf8.encode(content);
        } catch (e) {
          // If decoding fails, it's not a text file or not UTF-8,
          // so don't attempt CRLF conversion.
        }
      }
      return buffer;
    } catch (e) {
      // print('Error in FileSystem.read: $e');
      return null;
    }
  }

  /// Writes [contents] to a file at [filepath].
  ///
  /// [contents] can be a `String` or `Uint8List`.
  /// If [contents] is a `String`, [encoding] (defaulting to utf8) is used.
  /// Creates missing directories if necessary.
  Future<void> write(String filepath, dynamic contents, {Encoding encoding = utf8}) async {
    try {
      final file = File(filepath);
      // Ensure the parent directory exists
      final parentDir = Directory(p.dirname(filepath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      if (contents is String) {
        await file.writeAsString(contents, encoding: encoding, flush: true);
      } else if (contents is Uint8List) {
        await file.writeAsBytes(contents, flush: true);
      } else {
        throw ArgumentError('Contents must be a String or Uint8List');
      }
    } catch (e) {
      // print('Error in FileSystem.write: $e');
      // Potentially rethrow or handle specific errors
      // For now, if the first write fails after mkdir, let it throw
      // This matches the JS version's behavior of trying mkdir then write again,
      // but dart:io's recursive create should handle most cases.
      rethrow;
    }
  }

  /// Creates a directory (or series of nested directories) at [filepath].
  /// Does not throw an error if the directory already exists.
  Future<void> mkdir(String filepath) async {
    try {
      final dir = Directory(filepath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      // print('Error in FileSystem.mkdir: $e');
      // The recursive create should handle most cases, including EEXIST implicitly.
      // If it still throws, it's likely a more serious issue (e.g., permissions).
      rethrow;
    }
  }

  /// Deletes a file at [filepath].
  /// Does not throw an error if the file is already deleted.
  Future<void> rm(String filepath) async {
    try {
      final file = File(filepath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != 2 /* ENOENT */) {
        // print('Error in FileSystem.rm: $e');
        rethrow;
      }
      // If ENOENT, do nothing (file already deleted)
    }
  }

  /// Deletes a directory at [filepath].
  /// If [recursive] is true, deletes contents as well.
  /// Does not throw an error if the directory is already deleted.
  Future<void> rmdir(String filepath, {bool recursive = false}) async {
    try {
      final dir = Directory(filepath);
      if (await dir.exists()) {
        await dir.delete(recursive: recursive);
      }
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode != 2 /* ENOENT */) {
        // print('Error in FileSystem.rmdir: $e');
        rethrow;
      }
      // If ENOENT, do nothing (directory already deleted)
    }
  }

  /// Reads the names of entries in a directory at [filepath].
  /// Returns an empty list if the directory doesn't exist or is not a directory.
  Future<List<String>> readdir(String filepath) async {
    try {
      final dir = Directory(filepath);
      if (await dir.exists()) {
        final List<String> names = [];
        await for (final entity in dir.list()) {
          names.add(p.basename(entity.path));
        }
        // The JS version sorts these, let's do the same for consistency.
        // It uses `compareStrings`, which is a locale-sensitive sort.
        // Dart's default String.compareTo is usually sufficient for filenames.
        names.sort(); 
        return names;
      }
      return [];
    } catch (e) {
      // print('Error in FileSystem.readdir: $e');
      return [];
    }
  }

  /// Gets `FileStat` for the entity at [filepath], without following symlinks.
  /// Returns `null` if the entity doesn't exist or an error occurs.
  Future<FileStat?> lstat(String filepath) async {
    try {
      return await FileStat.stat(filepath);
    } catch (e) {
      // print('Error in FileSystem.lstat: $e');
      return null;
    }
  }

  /// Gets `FileStat` for the entity at [filepath], following symlinks for files.
  /// Returns `null` if the entity doesn't exist or an error occurs.
  Future<FileStat?> stat(String filepath) async {
    try {
      // For non-links, statSync behaves like lstatSync.
      // For links, statSync stats the linked target.
      return await FileStat.stat(filepath); 
    } catch (e) {
      // print('Error in FileSystem.stat: $e');
      return null;
    }
  }

  /// Reads the target of a symbolic link at [filepath].
  /// Returns `null` if the entity isn't a link or an error occurs.
  Future<String?> readlink(String filepath) async {
    try {
      final link = Link(filepath);
      if (await link.exists()) {
        return await link.target();
      }
      return null;
    } catch (e) {
      // print('Error in FileSystem.readlink: $e');
      return null;
    }
  }

  /// Creates a symbolic link at [filepath] pointing to [target].
  Future<void> symlink(String target, String filepath) async {
    try {
      final link = Link(filepath);
      final parentDir = Directory(p.dirname(filepath));
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await link.create(target);
    } catch (e) {
      // print('Error in FileSystem.symlink: $e');
      rethrow;
    }
  }
}