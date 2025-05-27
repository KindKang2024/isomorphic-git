import 'dart:io'; // For Directory and File, assuming 'fs' is similar to dart:io

// Assuming fs is an object that has a readdir method similar to dart:io.Directory.list
// This is a placeholder for the actual implementation.
class FileSystem {
  Future<List<String>> readdir(String path) async {
    final dir = Directory(path);
    final entities = await dir.list().toList();
    return entities.map((e) => e.path.split('/').last).toList();
  }
}

Future<List<String>> expandOidLoose({
  required FileSystem fs,
  required String gitdir,
  required String oid,
}) async {
  final prefix = oid.substring(0, 2);
  // In Dart, readdir might return full paths or just names depending on implementation.
  // The original JS code implies it gets suffixes, so we might need to adjust.
  final objectsSuffixes = await fs.readdir('$gitdir/objects/$prefix');

  return objectsSuffixes
      .map((suffix) => '$prefix$suffix')
      .where((_oid) => _oid.startsWith(oid))
      .toList();
}
