import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:path/path.dart' as p;

/// A FileSystem class that acts as a proxy to an underlying filesystem implementation.
/// This mimics the JavaScript version's approach of wrapping filesystem operations
/// while providing higher-level convenience methods.
class FileSystem {
  final FileSystemAdapter _fs;
  
  /// Creates a FileSystem instance with the provided adapter.
  /// If [fs] is already a FileSystem, returns it directly to avoid double-wrapping.
  FileSystem(FileSystemAdapter fs) : _fs = fs {
    // Store reference to original unwrapped fs (mimicking JS behavior)
    _fs._originalUnwrappedFs = fs;
  }

  /// Factory method to create a FileSystem with dart:io implementation
  factory FileSystem.dartIO() {
    return FileSystem(DartIOFileSystemAdapter());
  }

  /// Return true if a file exists, false if it doesn't exist.
  /// Rethrows errors that aren't related to file existence.
  Future<bool> exists(String filepath) async {
    try {
      await _fs.stat(filepath);
      return true;
    } catch (err) {
      if (err is FileSystemException &&
          (err.osError?.errorCode == 2 || // ENOENT
           err.osError?.errorCode == 20)) { // ENOTDIR
        return false;
      } else {
        print('Unhandled error in "FileSystem.exists()" function: $err');
        rethrow;
      }
    }
  }

  /// Return the contents of a file if it exists, otherwise returns null.
  Future<Uint8List?> read(String filepath, {bool autocrlf = false}) async {
    try {
      Uint8List buffer = await _fs.readFile(filepath);
      
      if (autocrlf) {
        try {
          String content = utf8.decode(buffer, allowMalformed: false);
          content = content.replaceAll('\r\n', '\n');
          buffer = utf8.encode(content);
        } catch (error) {
          // non utf8 file, skip conversion
        }
      }
      
      return buffer;
    } catch (err) {
      return null;
    }
  }

  /// Write a file (creating missing directories if need be) without throwing errors.
  Future<void> write(String filepath, dynamic contents, {Encoding encoding = utf8}) async {
    try {
      await _fs.writeFile(filepath, contents, encoding);
    } catch (err) {
      // Try creating parent directory and try again
      await mkdir(p.dirname(filepath));
      await _fs.writeFile(filepath, contents, encoding);
    }
  }

  /// Make a directory (or series of nested directories) without throwing an error if it already exists.
  Future<void> mkdir(String filepath, [bool _selfCall = false]) async {
    try {
      await _fs.mkdir(filepath);
    } catch (err) {
      if (err == null) return; // Operation succeeded
      
      if (err is FileSystemException && err.osError?.errorCode == 17) { // EEXIST
        return; // Directory already exists
      }
      
      if (_selfCall) rethrow; // Avoid infinite loops
      
      if (err is FileSystemException && err.osError?.errorCode == 2) { // ENOENT
        final parent = p.dirname(filepath);
        // Check to see if we've gone too far
        if (parent == '.' || parent == '/' || parent == filepath) rethrow;
        
        // Recursive creation
        await mkdir(parent);
        await mkdir(filepath, true);
      }
    }
  }

  /// Delete a file without throwing an error if it is already deleted.
  Future<void> rm(String filepath) async {
    try {
      await _fs.unlink(filepath);
    } catch (err) {
      if (err is FileSystemException && err.osError?.errorCode != 2) { // Not ENOENT
        rethrow;
      }
    }
  }

  /// Delete a directory without throwing an error if it is already deleted.
  Future<void> rmdir(String filepath, {bool recursive = false}) async {
    try {
        await _fs.rm(filepath, recursive: recursive);
    } catch (err) {
      if (err is FileSystemException && err.osError?.errorCode != 2) { // Not ENOENT
        rethrow;
      }
    }
  }

  /// Read a directory without throwing an error if the directory doesn't exist
  Future<List<String>> readdir(String filepath) async {
    try {
      final names = await _fs.readdir(filepath);
      // Ordering is not guaranteed, so we must sort them ourselves
      names.sort();
      return names;
    } catch (err) {
      if (err is FileSystemException && err.osError?.errorCode == 20) { // ENOTDIR
        return [];
      }
      return [];
    }
  }

  /// Return a flat list of all the files nested inside a directory
  Future<List<String>> readdirDeep(String dir) async {
    final subdirs = await _fs.readdir(dir);
    final List<String> allFiles = [];
    
    for (final subdir in subdirs) {
      final res = p.join(dir, subdir);
      final stat = await _fs.stat(res);
      if (stat.type == FileSystemEntityType.directory) {
        final deepFiles = await readdirDeep(res);
        allFiles.addAll(deepFiles);
      } else {
        allFiles.add(res);
      }
    }
    
    return allFiles;
  }

  /// Return the Stats of a file/symlink if it exists, otherwise returns null.
  Future<FileStat?> lstat(String filename) async {
    try {
      return await _fs.lstat(filename);
    } catch (err) {
      if (err is FileSystemException && err.osError?.errorCode == 2) { // ENOENT
        return null;
      }
      rethrow;
    }
  }

  /// Reads the contents of a symlink if it exists, otherwise returns null.
  Future<String?> readlink(String filename) async {
    try {
      return await _fs.readlink(filename);
    } catch (err) {
      if (err is FileSystemException && err.osError?.errorCode == 2) { // ENOENT
        return null;
      }
      rethrow;
    }
  }

  /// Write the contents of buffer to a symlink.
  Future<void> writelink(String filename, Uint8List buffer) async {
    return await _fs.symlink(utf8.decode(buffer), filename);
  }
}

/// Abstract adapter interface that defines the core filesystem operations
abstract class FileSystemAdapter {
  dynamic _originalUnwrappedFs;
  
  Future<Uint8List> readFile(String filepath);
  Future<void> writeFile(String filepath, dynamic contents, Encoding encoding);
  Future<void> mkdir(String filepath);
  Future<void> rmdir(String filepath);
  Future<void> unlink(String filepath);
  Future<FileStat> stat(String filepath);
  Future<FileStat> lstat(String filepath);
  Future<List<String>> readdir(String filepath);
  Future<String> readlink(String filepath);
  Future<void> symlink(String target, String filepath);
  
  // Optional rm method (some filesystems may not have it)
  Future<void> rm(String filepath, {bool recursive}) ;
}

/// Concrete implementation using dart:io
class DartIOFileSystemAdapter extends FileSystemAdapter {
  @override
  Future<Uint8List> readFile(String filepath) async {
    final file = File(filepath);
    return await file.readAsBytes();
  }

  @override
  Future<void> writeFile(String filepath, dynamic contents, Encoding encoding) async {
    final file = File(filepath);
    if (contents is String) {
      await file.writeAsString(contents, encoding: encoding);
    } else if (contents is Uint8List) {
      await file.writeAsBytes(contents);
    } else {
      throw ArgumentError('Contents must be String or Uint8List');
    }
  }

  @override
  Future<void> mkdir(String filepath) async {
    final dir = Directory(filepath);
    await dir.create();
  }

  @override
  Future<void> rmdir(String filepath) async {
    final dir = Directory(filepath);
    await dir.delete();
  }

  @override
  Future<void> unlink(String filepath) async {
    final file = File(filepath);
    await file.delete();
  }

  @override
  Future<FileStat> stat(String filepath) async {
    return await FileStat.stat(filepath);
  }

  @override
  Future<FileStat> lstat(String filepath) async {
    return await FileStat.stat(filepath);
  }

  @override
  Future<List<String>> readdir(String filepath) async {
    final dir = Directory(filepath);
    final List<String> names = [];
    await for (final entity in dir.list()) {
      names.add(p.basename(entity.path));
    }
    return names;
  }

  @override
  Future<String> readlink(String filepath) async {
    final link = Link(filepath);
    return await link.target();
  }

  @override
  Future<void> symlink(String target, String filepath) async {
    final link = Link(filepath);
    await link.create(target);
  }

  @override
  Future<void> rm(String filepath, {bool recursive = false}) async {
    final entity = await FileSystemEntity.type(filepath);
    if (entity == FileSystemEntityType.directory) {
      final dir = Directory(filepath);
      await dir.delete(recursive: recursive);
    } else {
      final file = File(filepath);
      await file.delete();
    }
  }
}