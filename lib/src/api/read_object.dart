import 'dart:convert';
import 'dart:typed_data';

import '../errors/object_type_error.dart';
import '../models/file_system.dart';
import '../models/git_annotated_tag.dart';
import '../models/git_commit.dart';
import '../models/git_tree.dart';
import '../storage/read_object.dart'; // _readObject
import '../utils/assert_parameter.dart';
import '../utils/join.dart';
import '../utils/resolve_filepath.dart';

// Definitions for result types
class DeflatedObject {
  String oid;
  String type = 'deflated';
  String format = 'deflated';
  Uint8List object;
  String? source;
  DeflatedObject({required this.oid, required this.object, this.source});
}

class WrappedObject {
  String oid;
  String type = 'wrapped';
  String format = 'wrapped';
  Uint8List object;
  String? source;
  WrappedObject({required this.oid, required this.object, this.source});
}

class RawObject {
  String oid;
  String type; // 'blob'|'commit'|'tree'|'tag'
  String format = 'content';
  Uint8List object;
  String? source;
  RawObject({
    required this.oid,
    required this.type,
    required this.object,
    this.source,
  });
}

class ParsedBlobObject {
  String oid;
  String type = 'blob';
  String format = 'parsed';
  dynamic object; // String or Uint8List depending on encoding
  String? source;
  ParsedBlobObject({required this.oid, required this.object, this.source});
}

class ParsedCommitObject {
  String oid;
  String type = 'commit';
  String format = 'parsed';
  GitCommit object; // Assuming CommitObject is aliased or is GitCommit
  String? source;
  ParsedCommitObject({required this.oid, required this.object, this.source});
}

class ParsedTreeObject {
  String oid;
  String type = 'tree';
  String format = 'parsed';
  GitTree object; // Assuming TreeObject is aliased or is GitTree
  String? source;
  ParsedTreeObject({required this.oid, required this.object, this.source});
}

class ParsedTagObject {
  String oid;
  String type = 'tag';
  String format = 'parsed';
  GitAnnotatedTag object; // Assuming TagObject is aliased or is GitAnnotatedTag
  String? source;
  ParsedTagObject({required this.oid, required this.object, this.source});
}

// Union type equivalent for ReadObjectResult
// In Dart, this would typically be a base class or interface, or handled by `dynamic` and type checking.
// For simplicity, we'll use `dynamic` as the return type for the main function and the caller can perform type checks.

@Deprecated(
  'This command is overly complicated. Use specific read methods if object type is known.',
)
Future<dynamic> readObject({
  required dynamic fs,
  String? dir,
  String? gitdir,
  required String oid,
  String format = 'parsed',
  String? filepath,
  String? encoding,
  Map<String, dynamic> cache = const {},
}) async {
  final fsModel = FileSystem(fs);
  final String effectiveGitdir = gitdir ?? join(dir, '.git');

  try {
    assertParameter('fs', fs);
    assertParameter('gitdir', effectiveGitdir);
    assertParameter('oid', oid);

    String _oid = oid;
    String? _filepath = filepath;

    if (filepath != null) {
      _oid = await resolveFilepath(
        fs: fsModel,
        gitdir: effectiveGitdir,
        oid: oid,
        filepath: filepath,
      );
      _filepath =
          null; // We've resolved the filepath to an oid, so we pass null for filepath to _readObject
    }

    var result = await _readObject(
      fs: fsModel,
      cache: cache,
      gitdir: effectiveGitdir,
      oid: _oid,
      formatHint: format,
      filepath:
          _filepath, // This should be null if original filepath was used for resolveFilepath
      encoding: encoding,
    );

    // The _readObject in JS returns an object with oid, type, format, object, source.
    // We need to reconstruct the specific Dart classes based on 'format' and 'type'.

    String resultOid = result['oid'];
    String resultType = result['type'];
    String resultFormat = result['format'];
    dynamic resultObject = result['object'];
    String? resultSource = result['source'];

    if (resultFormat == 'deflated') {
      return DeflatedObject(
        oid: resultOid,
        object: resultObject as Uint8List,
        source: resultSource,
      );
    }
    if (resultFormat == 'wrapped') {
      return WrappedObject(
        oid: resultOid,
        object: resultObject as Uint8List,
        source: resultSource,
      );
    }
    if (resultFormat == 'content') {
      return RawObject(
        oid: resultOid,
        type: resultType,
        object: resultObject as Uint8List,
        source: resultSource,
      );
    }

    if (resultFormat == 'parsed') {
      if (resultType == 'blob') {
        // JS version converts to string if encoding is given, otherwise Uint8Array
        // Dart _readObject should ideally handle this logic or return Uint8List always for parsed blobs
        return ParsedBlobObject(
          oid: resultOid,
          object: resultObject,
          source: resultSource,
        );
      } else if (resultType == 'commit') {
        // Assuming resultObject is already a GitCommit instance or can be cast
        return ParsedCommitObject(
          oid: resultOid,
          object: GitCommit.fromMap(resultObject),
          source: resultSource,
        );
      } else if (resultType == 'tree') {
        // Assuming resultObject is already a GitTree instance or can be cast
        return ParsedTreeObject(
          oid: resultOid,
          object: GitTree.fromMap(resultObject),
          source: resultSource,
        );
      } else if (resultType == 'tag') {
        // Assuming resultObject is already a GitAnnotatedTag instance or can be cast
        return ParsedTagObject(
          oid: resultOid,
          object: GitAnnotatedTag.fromMap(resultObject),
          source: resultSource,
        );
      }
    }

    // Fallback or error if format/type combination is unexpected.
    // The original JS code seems to rely on _readObject to correctly form the object.
    // This transformation logic might need to be closer to how _readObject structures its return in Dart.
    throw Exception(
      'Unknown object format or type combination: $resultFormat, $resultType',
    );
  } catch (e) {
    if (e is ObjectTypeError) {
      // Original JS code modifies the error object with a caller. In Dart, we'd typically rethrow or wrap.
      // err.caller = 'git.readObject' // JS style
      rethrow; // Or throw a new error that wraps e and includes context.
    }
    // err.caller = 'git.readObject' // JS style
    rethrow;
  }
}
