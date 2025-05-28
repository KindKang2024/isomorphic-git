import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

// Import your Dart git library functions
// You'll need to adjust these imports based on your actual library structure
import 'package:isomorphic_git/src/commands/init.dart';
import 'helpers/fixture_fs.dart'; // You'll need to create this helper
import 'package:isomorphic_git/src/api/set_config.dart';
import 'package:isomorphic_git/src/commands/get_config.dart';


void main() {
  group('init', () {
    test('init', () async {
      // Setup
      final fixture = await makeFixture('test-init');
      final fs = fixture.fs;
      final dir = fixture.dir;
      
      // Test
      await init(fs: fs, dir: dir);
      
      expect(Directory(dir).existsSync(), isTrue);
      expect(Directory(path.join(dir, '.git', 'objects')).existsSync(), isTrue);
      expect(Directory(path.join(dir, '.git', 'refs', 'heads')).existsSync(), isTrue);
      expect(File(path.join(dir, '.git', 'HEAD')).existsSync(), isTrue);
    });

    test('init --bare', () async {
      // Setup
      final fixture = await makeFixture('test-init');
      final fs = fixture.fs;
      final dir = fixture.dir;
      
      // Test
      await init(fs: fs, dir: dir, bare: true);
      
      expect(Directory(dir).existsSync(), isTrue);
      expect(Directory(path.join(dir, 'objects')).existsSync(), isTrue);
      expect(Directory(path.join(dir, 'refs', 'heads')).existsSync(), isTrue);
      expect(File(path.join(dir, 'HEAD')).existsSync(), isTrue);
    });

    test('init does not overwrite existing config', () async {
      // Setup
      final fixture = await makeFixture('test-init');
      final fs = fixture.fs;
      final dir = fixture.dir;
      const name = 'me';
      const email = 'meme';
      
      await init(fs: fs, dir: dir);
      expect(Directory(dir).existsSync(), isTrue);
      expect(File(path.join(dir, '.git', 'config')).existsSync(), isTrue);
      
      await setConfig(fs: fs, dir: dir, path: 'user.name', value: name);
      await setConfig(fs: fs, dir: dir, path: 'user.email', value: email);
      
      // Test
      await init(fs: fs, dir: dir);
      expect(Directory(dir).existsSync(), isTrue);
      expect(File(path.join(dir, '.git', 'config')).existsSync(), isTrue);
      
      // Check that the properties we added are still there
      expect(await getConfig(fs: fs, dir: dir, path: 'user.name'), equals(name));
      expect(await getConfig(fs: fs, dir: dir, path: 'user.email'), equals(email));
    });
  });
}