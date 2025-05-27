import 'dart:io'; // For File.exists

// Placeholder for FileSystem
// Assuming fs.exists is similar to File(path).exists()
class FileSystem {
  Future<bool> exists(String path) async {
    return File(path).exists();
  }
}

Future<bool> hasObjectLoose({
  required FileSystem fs,
  required String gitdir,
  required String oid,
}) async {
  final source = 'objects/${oid.substring(0, 2)}/${oid.substring(2)}';
  return fs.exists('$gitdir/$source');
}
