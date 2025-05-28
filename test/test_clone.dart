import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

// Import your Dart git library functions
import 'package:isomorphic_git/src/api/clone.dart';
import 'package:isomorphic_git/src/api/checkout.dart';
import 'package:isomorphic_git/src/api/current_branch.dart';
import 'package:isomorphic_git/src/api/resolve_ref.dart';
import 'package:isomorphic_git/src/api/get_config.dart';
import 'package:isomorphic_git/src/errors/git_errors.dart';
import 'package:isomorphic_git/src/errors/commit_not_fetched_error.dart';
import 'helpers/fixture_fs.dart';

void main() {
  // Mock localhost for testing
  const localhost = 'localhost';
  
  // Create a simple HTTP client for testing
  final http = createHttpClient();

  group('clone', () {
    test('clone with noTags', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        ref: 'test-branch',
        noTags: true,
        url: 'https://github.com/isomorphic-git/isomorphic-git.git',
        noCheckout: true,
      );
      
      expect(await fs.exists(dir), isTrue);
      expect(await fs.exists(path.join(gitdir, 'objects')), isTrue);
      expect(
        await resolveRef(fs: fs, gitdir: gitdir, ref: 'refs/remotes/origin/test-branch'),
        equals('e10ebb90d03eaacca84de1af0a59b444232da99e'),
      );
      expect(
        await resolveRef(fs: fs, gitdir: gitdir, ref: 'refs/heads/test-branch'),
        equals('e10ebb90d03eaacca84de1af0a59b444232da99e'),
      );
      
      dynamic err;
      try {
        await resolveRef(fs: fs, gitdir: gitdir, ref: 'refs/tags/v0.0.1');
      } catch (e) {
        err = e;
      }
      expect(err, isNotNull);
      expect(err, isA<NotFoundError>());
    });

    test('clone with noCheckout', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        ref: 'test-branch',
        singleBranch: true,
        noCheckout: true,
        url: 'https://github.com/isomorphic-git/isomorphic-git.git',
      );
      
      expect(await fs.exists(dir), isTrue);
      expect(await fs.exists(path.join(gitdir, 'objects')), isTrue);
      expect(await fs.exists(path.join(gitdir, 'refs/remotes/origin/test-branch')), isTrue);
      expect(await fs.exists(path.join(gitdir, 'refs/heads/test-branch')), isTrue);
      expect(await fs.exists(path.join(dir, 'package.json')), isFalse);
    });

    test('clone a tag', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        singleBranch: true,
        ref: 'test-tag',
        url: 'https://github.com/isomorphic-git/isomorphic-git.git',
      );
      
      expect(await fs.exists(dir), isTrue);
      expect(await fs.exists(path.join(gitdir, 'objects')), isTrue);
      expect(await fs.exists(path.join(gitdir, 'refs/remotes/origin/test-tag')), isFalse);
      expect(await fs.exists(path.join(gitdir, 'refs/heads/test-tag')), isFalse);
      expect(await fs.exists(path.join(gitdir, 'refs/tags/test-tag')), isTrue);
      expect(await fs.exists(path.join(dir, 'package.json')), isTrue);
    });

    test('clone should not peel tag', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        url: 'http://$localhost:8888/test-git-http-mock-server.git',
      );
      
      final oid = await fs.read(path.join(gitdir, 'refs/tags/v1.0.0'), encoding: 'utf8');
      expect(oid.trim(), equals('db34227a52a6490fc80a13da3916ea91d183fc3f'));
    });

    test('clone with an unregistered protocol', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      const url = 'foobar://github.com/isomorphic-git/isomorphic-git';
      
      dynamic error;
      try {
        await clone(
          fs: fs,
          http: http,
          dir: dir,
          gitdir: gitdir,
          depth: 1,
          singleBranch: true,
          ref: 'test-tag',
          url: url,
        );
      } catch (err) {
        error = err;
      }
      
      expect(error, isNotNull);
      expect(error.toString(), contains('Git remote "$url" uses an unrecognized transport protocol: "foobar"'));
    });

    test('clone from git-http-mock-server', () async {
      final fixture = await makeFixture('test-clone-karma');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        singleBranch: true,
        url: 'http://$localhost:8888/test-clone.git',
      );
      
      expect(await fs.exists(dir), isTrue, reason: "'dir' exists");
      expect(await fs.exists(path.join(gitdir, 'objects')), isTrue, reason: "'gitdir/objects' exists");
      expect(await fs.exists(path.join(gitdir, 'refs/heads/master')), isTrue, reason: "'gitdir/refs/heads/master' exists");
      expect(await fs.exists(path.join(dir, 'a.txt')), isTrue, reason: "'a.txt' exists");
    });

    test('should not throw TypeError error if packfile is empty', () async {
      final fixture = await makeFixture('test-clone-error-empty-packfile');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      // Create a mock HTTP client that simulates empty packfile
      final instrumentedHttp = createMockHttpClient(emptyPackfile: true);
      
      dynamic error;
      try {
        await clone(
          fs: fs,
          http: instrumentedHttp,
          dir: dir,
          gitdir: gitdir,
          depth: 1,
          singleBranch: true,
          url: 'http://$localhost:8888/test-clone.git',
        );
      } catch (e) {
        error = e;
      }
      
      expect(error, isNotNull);
      expect(error, isNot(isA<TypeError>()));
      expect(error, isA<CommitNotFetchedError>());
    });

    test('clone default branch with --singleBranch', () async {
      final fixture = await makeFixture('test-clone-karma');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        singleBranch: true,
        url: 'http://$localhost:8888/test-clone-no-master.git',
      );
      
      expect(await currentBranch(fs: fs, dir: dir, gitdir: gitdir), equals('i-am-not-master'));
    });

    test('create tracking for remote branch', () async {
      final fixture = await makeFixture('test-clone-branch-with-dot');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        url: 'http://$localhost:8888/test-branch-with-dot.git',
      );
      
      await checkout(fs: fs, dir: dir, gitdir: gitdir, ref: 'v1.0.x');
      final config = await fs.read(path.join(gitdir, 'config'), encoding: 'utf8');
      expect(config, contains('\n[branch "v1.0.x"]\n\tmerge = refs/heads/v1.0.x\n\tremote = origin'));
    });

    test('clone empty repository from git-http-mock-server', () async {
      final fixture = await makeFixture('test-clone-empty');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        url: 'http://$localhost:8888/test-empty.git',
      );
      
      expect(await fs.exists(dir), isTrue, reason: "'dir' exists");
      expect(await fs.exists(path.join(gitdir, 'HEAD')), isTrue, reason: "'gitdir/HEAD' exists");
      final headContent = await fs.read(path.join(gitdir, 'HEAD'), encoding: 'utf8');
      expect(headContent.trim(), equals('ref: refs/heads/master'), reason: "'gitdir/HEAD' points to refs/heads/master");
      expect(await fs.exists(path.join(gitdir, 'refs/heads/master')), isFalse, reason: "'gitdir/refs/heads/master' does not exist");
    });

    test('removes the gitdir when clone fails', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      const url = 'foobar://github.com/isomorphic-git/isomorphic-git';
      
      try {
        await clone(
          fs: fs,
          http: http,
          dir: dir,
          gitdir: gitdir,
          depth: 1,
          singleBranch: true,
          ref: 'test-tag',
          url: url,
        );
      } catch (err) {
        // Intentionally left blank.
      }
      
      expect(await fs.exists(gitdir), isFalse, reason: "'gitdir' does not exist");
    });

    test('should set up the remote tracking branch by default', () async {
      final fixture = await makeFixture('isomorphic-git');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        singleBranch: true,
        remote: 'foo',
        url: 'https://github.com/isomorphic-git/isomorphic-git.git',
      );

      final merge = await getConfig(fs: fs, dir: dir, gitdir: gitdir, path: 'branch.main.merge');
      final remote = await getConfig(fs: fs, dir: dir, gitdir: gitdir, path: 'branch.main.remote');

      expect(merge, equals('refs/heads/main'));
      expect(remote, equals('foo'));
    });

    test('clone with post-checkout hook', () async {
      final fixture = await makeFixture('test-clone-karma');
      final fs = fixture.fs;
      final dir = fixture.dir;
      final gitdir = path.join(dir, '.git');
      final onPostCheckout = <Map<String, dynamic>>[];
      
      await clone(
        fs: fs,
        http: http,
        dir: dir,
        gitdir: gitdir,
        depth: 1,
        singleBranch: true,
        url: 'http://$localhost:8888/test-clone.git',
        onPostCheckout: (args) async {
          onPostCheckout.add(args);
        },
      );

      expect(onPostCheckout, equals([
        {
          'newHead': '97c024f73eaab2781bf3691597bc7c833cb0e22f',
          'previousHead': '0000000000000000000000000000000000000000',
          'type': 'branch',
        },
      ]));
    });
  });
}

// Helper function to create a mock HTTP client for testing
HttpClient createMockHttpClient({bool emptyPackfile = false}) {
  // This would need to be implemented based on your HttpClient interface
  // For now, returning a basic implementation
  return createHttpClient();
}