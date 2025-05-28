import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import '../errors/internal_error.dart';
import '../errors/not_found_error.dart';
import '../models/git_object.dart';
import '../models/file_system.dart'; // Assuming a file system shim
import '../utils/inflate.dart'; // Assuming an inflate utility
import '../utils/shasum.dart';   // Assuming a shasum utility

import 'read_object_loose.dart'; // Assuming this will be created
import 'read_object_packed.dart';

// Define a class for the result structure if not already defined
// This could be part of GitObject or a separate class
class ReadObjectResult {
  String format;
  Uint8List object;
  String? type;
  String? source; // Optional: to indicate where the object was found

  ReadObjectResult({
    required this.format,
    required this.object,
    this.type,
    this.source,
  });
}

Future<ReadObjectResult> readObject({
  required FileSystem fs,
  // cache is not directly used here as sub-functions handle their caching
  required String gitdir,
  required String oid,
  String format = 'content', // Default format
}) async {
  // Curry the current read method for external ref-deltas
  Future<Uint8List> getExternalRefDelta(String externalOid) async {
    final result = await readObject(
      fs: fs,
      gitdir: gitdir,
      oid: externalOid,
      format: 'wrapped', // Deltas need the wrapped format
    );
    return result.object;
  }

  ReadObjectResult? result;

  // Empty tree - hard-coded
  if (oid == '4b825dc642cb6eb9a060e54bf8d69288fbee4904') {
    result = ReadObjectResult(
      format: 'wrapped',
      object: Uint8List.fromList(utf8.encode('tree 0\x00')),
    );
  }

  // Look for it in the loose object directory.
  if (result == null) {
    // Assuming readObjectLoose returns a ReadObjectResult or similar
    // You'll need to create read_object_loose.dart
    final looseObject = await readObjectLoose(fs: fs, gitdir: gitdir, oid: oid);
    if (looseObject != null) {
       result = ReadObjectResult(format: looseObject.format, object: looseObject.object, type: looseObject.type);
    }
  }

  // Check to see if it's in a packfile.
  if (result == null) {
    final packedResult = await readObjectPacked(
      fs: fs,
      gitdir: gitdir,
      oid: oid,
      getExternalRefDelta: getExternalRefDelta,
    );

    if (packedResult == null) {
      throw NotFoundError(oid);
    }
    // Packed objects are always 'content' format as per original JS
    // and include type directly from packfile reading logic.
    return ReadObjectResult(
        format: packedResult.format,
        object: packedResult.object,
        type: packedResult.type,
        source: packedResult.source);
  }

  // Loose objects are always deflated, return early if that's the requested format
  if (format == 'deflated') {
    if (result.format != 'deflated') {
        // This case should ideally be handled by readObjectLoose if it returns 'deflated' format
        throw InternalError('Expected deflated format but got ${result.format}');
    }
    return result;
  }

  // Inflate if necessary (loose objects are deflated, hard-coded empty tree is 'wrapped')
  if (result.format == 'deflated') {
    result.object = await inflate(result.object); // Assuming inflate utility
    result.format = 'wrapped';
  }

  if (format == 'wrapped') {
    return result;
  }

  // If 'content' format is requested, unwrap and verify SHA
  final String computedSha = await shasum(result.object); // Assuming shasum utility
  if (computedSha != oid) {
    throw InternalError('SHA check failed! Expected $oid, computed $computedSha');
  }

  final unwrapped = GitObject.unwrap(result.object); // Assuming GitObject.unwrap
  result.type = unwrapped.type;
  result.object = unwrapped.object;
  result.format = 'content';

  if (format == 'content') {
    return result;
  }

  throw InternalError('Invalid requested format "$format"');
}