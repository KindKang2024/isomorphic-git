import 'dart:io';
import 'package:isomorphic_git/src/models/file_system.dart';
import 'package:path/path.dart' as path;

class Fixture {
  final FileSystem fs;
  final String dir;
  
  Fixture({required this.fs, required this.dir});
}

Future<Fixture> makeFixture(String fixtureName) async {
  // Create a temporary directory for testing
  final tempDir = await Directory.systemTemp.createTemp('git_test_');
  final fs = createFileSystem();
  
  return Fixture(fs: fs, dir: tempDir.path);
}

// Create a basic FileSystem implementation for testing
FileSystem createFileSystem() {
  return FileSystem.dartIO();
}

// Basic implementation of file system client
class DartFileSystemClient {
  Future<void> write(String filepath, dynamic data) async {
    final file = File(filepath);
    await file.parent.create(recursive: true);
    if (data is String) {
      await file.writeAsString(data);
    } else {
      await file.writeAsBytes(data);
    }
  }

  Future<dynamic> read(String filepath) async {
    final file = File(filepath);
    return await file.readAsString();
  }

  Future<bool> exists(String filepath) async {
    return await File(filepath).exists() || await Directory(filepath).exists();
  }

  Future<void> rm(String filepath) async {
    final file = File(filepath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

// Create a basic HTTP client for testing
HttpClient createHttpClient() {
  // This should return an instance of your HttpClient implementation
  // You may need to create a mock or test implementation
  throw UnimplementedError('createHttpClient needs to be implemented based on your HttpClient interface');
}