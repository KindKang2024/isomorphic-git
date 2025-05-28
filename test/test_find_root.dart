import 'package:test/test.dart';
import 'package:isomorphic_git/isomorphic_git.dart'; // Adjust if necessary
import 'dart:io';
import 'package:path/path.dart' as p;

import 'dart:io';
import 'package:isomorphic_git/src/api/find_root.dart';
import 'package:isomorphic_git/src/models/file_system.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
// We are not using FixtureFS from helpers, but FileSystem.dartIO() directly.
// import '../helpers/fixture_fs.dart'; 

// TestFixture class definition
class TestFixture {
  final FileSystem fs; // Will be an instance of FileSystem.dartIO()
  final String path;   // Path to the actual temporary directory root
  final Directory dirHandle; // The Directory object for direct operations and cleanup

  TestFixture(this.fs, this.path, this.dirHandle);
}

// makeFixture function definition
Future<TestFixture> makeFixture(String? testNameSuffix) async {
  final tempDir = Directory.systemTemp.createTempSync('find_root_test_${testNameSuffix ?? "fixture"}');
  final fs = FileSystem.dartIO(); // Using the dart:io backed FileSystem

  // Create the base 'foobar/bar/baz/buzz' structure directly using dart:io
  // because fixture.fs will operate on these real directories.
  await Directory(p.join(tempDir.path, 'foobar', 'bar', 'baz', 'buzz')).create(recursive: true);

  return TestFixture(fs, tempDir.path, tempDir);
}

void main() {
  group('findRoot', () {
    group('filepath has its own .git folder', () {
      late TestFixture fixture;

      setUp(() async {
        fixture = await makeFixture('own_git_folder');
        // Create .git directories using dart:io.Directory
        await Directory(p.join(fixture.path, 'foobar', '.git')).create();
        await Directory(p.join(fixture.path, 'foobar', 'bar', '.git')).create();
      });

      tearDown(() async {
        if (await fixture.dirHandle.exists()) {
          await fixture.dirHandle.delete(recursive: true);
        }
      });

      test('should find foobar', () async {
        final root = await findRoot(
          fs: fixture.fs, // Pass the FileSystem.dartIO() instance
          filepath: p.join(fixture.path, 'foobar'),
        );
        expect(p.basename(root), 'foobar');
      });
    });

    group('filepath has ancestor with a .git folder', () {
      late TestFixture fixture;

      setUp(() async {
        fixture = await makeFixture('ancestor_git_folder');
        // Create .git directories using dart:io.Directory
        // Note: The problem description for both test cases has the same .git setup.
        // foobar/.git and foobar/bar/.git
        await Directory(p.join(fixture.path, 'foobar', '.git')).create();
        await Directory(p.join(fixture.path, 'foobar', 'bar', '.git')).create();
      });

      tearDown(() async {
        if (await fixture.dirHandle.exists()) {
          await fixture.dirHandle.delete(recursive: true);
        }
      });

      test('should find bar', () async {
        final root = await findRoot(
          fs: fixture.fs, // Pass the FileSystem.dartIO() instance
          filepath: p.join(fixture.path, 'foobar', 'bar', 'baz', 'buzz'),
        );
        expect(p.basename(root), 'bar');
      });
    });
  });
}
