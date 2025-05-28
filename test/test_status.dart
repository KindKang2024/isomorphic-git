import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

// Import your Dart git library functions
import 'package:isomorphic_git/src/api/status.dart';
import 'package:isomorphic_git/src/api/add.dart';
import 'package:isomorphic_git/src/api/remove.dart';
import 'helpers/fixture_fs.dart';

void main() {
  group('status', () {
    test('status', () async {
      // Setup
      final fixture = await makeFixture('test-status');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      // Test
      final a = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      final b = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'b.txt');
      final c = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'c.txt');
      final d = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'd.txt');
      final e = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'e.txt');
      expect(a, equals('unmodified'));
      expect(b, equals('*modified'));
      expect(c, equals('*deleted'));
      expect(d, equals('*added'));
      expect(e, equals('absent'));

      await add(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      await add(fs: fs, dir: dir, gitdir: gitdir, filepath: 'b.txt');
      await remove(fs: fs, dir: dir, gitdir: gitdir, filepath: 'c.txt');
      await add(fs: fs, dir: dir, gitdir: gitdir, filepath: 'd.txt');
      final a2 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      final b2 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'b.txt');
      final c2 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'c.txt');
      final d2 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'd.txt');
      expect(a2, equals('unmodified'));
      expect(b2, equals('modified'));
      expect(c2, equals('deleted'));
      expect(d2, equals('added'));

      // And finally the weirdo cases
      final acontent = await fs.read(path.join(dir, 'a.txt'));
      await fs.write(path.join(dir, 'a.txt'), 'Hi');
      await add(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      await fs.write(path.join(dir, 'a.txt'), acontent);
      final a3 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      expect(a3, equals('*unmodified'));

      await remove(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      final a4 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      expect(a4, equals('*undeleted'));

      await fs.write(path.join(dir, 'e.txt'), 'Hi');
      await add(fs: fs, dir: dir, gitdir: gitdir, filepath: 'e.txt');
      await fs.rm(path.join(dir, 'e.txt'));
      final e3 = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'e.txt');
      expect(e3, equals('*absent'));

      // Yay .gitignore!
      // NOTE: make_http_index does not include hidden files, so
      // I had to insert test-status/.gitignore and test-status/i/.gitignore
      // manually into the JSON.
      final f = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'f.txt');
      final g = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'g/g.txt');
      final h = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'h/h.txt');
      final i = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'i/i.txt');
      expect(f, equals('ignored'));
      expect(g, equals('ignored'));
      expect(h, equals('ignored'));
      expect(i, equals('*added'));
    });

    test('status in an fresh git repo with no commits', () async {
      // Setup
      final fixture = await makeFixture('test-empty');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await fs.write(path.join(dir, 'a.txt'), 'Hi');
      await fs.write(path.join(dir, 'b.txt'), 'Hi');
      await add(fs: fs, dir: dir, gitdir: gitdir, filepath: 'b.txt');
      
      // Test
      final a = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'a.txt');
      expect(a, equals('*added'));
      final b = await status(fs: fs, dir: dir, gitdir: gitdir, filepath: 'b.txt');
      expect(b, equals('added'));
    });
  });
}