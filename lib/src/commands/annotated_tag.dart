import 'dart:async';

import '../errors/already_exists_error.dart';
import '../managers/git_ref_manager.dart';
import '../models/git_annotated_tag.dart';
import '../storage/read_object.dart' as read_object_command;
import '../storage/write_object.dart' as write_object_command;
import '../models/fs.dart'; // Assuming FsModel exists
import '../utils/typedefs.dart'; // For SignCallback

class Tagger {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  Tagger({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'timestamp': timestamp,
    'timezoneOffset': timezoneOffset,
  };
}

Future<void> annotatedTag({
  required FsModel fs,
  required Map<String, dynamic> cache, // Consider a typed Cache object
  SignCallback? onSign,
  required String gitdir,
  required String ref,
  Tagger? tagger,
  String? message,
  String? gpgsig,
  String?
  objectOid, // Renamed from 'object' to avoid conflict with Dart's Object
  String? signingKey,
  bool force = false,
}) async {
  String fullRef = ref.startsWith('refs/tags/') ? ref : 'refs/tags/$ref';
  message ??= ref.startsWith('refs/tags/') ? ref.substring(10) : ref;

  if (!force &&
      await GitRefManager.exists(fs: fs, gitdir: gitdir, ref: fullRef)) {
    throw AlreadyExistsError('tag', fullRef);
  }

  final resolvedOid = await GitRefManager.resolve(
    fs: fs,
    gitdir: gitdir,
    ref: objectOid ?? 'HEAD',
  );

  final objectReadResult = await read_object_command.readObject(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: resolvedOid,
  );
  // Assuming objectReadResult has a 'type' property
  final String type = objectReadResult.type;

  var tagObject = GitAnnotatedTag.fromMap({
    'object': resolvedOid,
    'type': type,
    'tag': fullRef.replaceFirst('refs/tags/', ''),
    'tagger': tagger?.toMap(),
    'message': message,
    'gpgsig': gpgsig,
  });

  if (signingKey != null && onSign != null) {
    tagObject = await GitAnnotatedTag.sign(tagObject, onSign, signingKey);
  }

  final value = await write_object_command.writeObject(
    fs: fs,
    gitdir: gitdir,
    type: 'tag',
    object: tagObject
        .toObject(), // Assuming toObject() returns a Uint8List or String
  );

  await GitRefManager.writeRef(
    fs: fs,
    gitdir: gitdir,
    ref: fullRef,
    value: value,
  );
}
