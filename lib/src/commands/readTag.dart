import '../errors/object_type_error.dart';
import '../models/git_annotated_tag.dart'; // Assuming this will be created
import '../storage/read_object.dart'; // Assuming this will be created

// TODO: Define these types or import them
typedef FileSystem = dynamic; // Placeholder
typedef Cache = dynamic; // Placeholder

// This corresponds to ReadTagResult in JS
class ReadTagResult {
  final String oid;
  final ParsedTagObject tag; // This will be the parsed tag data
  final String payload; // PGP signing payload

  ReadTagResult({required this.oid, required this.tag, required this.payload});
}

// This corresponds to TagObject in JS (the parsed tag)
// This should be defined in models/git_annotated_tag.dart or similar
class ParsedTagObject {
  final String object; // OID of the tagged object
  final String type; // type of the tagged object (e.g., 'commit')
  final String tag; // tag name
  final String tagger; // tagger information
  final String message; // tag message
  // Add gpgsig if needed based on GitAnnotatedTag.parse() result

  ParsedTagObject({
    required this.object,
    required this.type,
    required this.tag,
    required this.tagger,
    required this.message,
  });
}

Future<ReadTagResult> readTag({
  required FileSystem fs,
  required Cache cache,
  required String gitdir,
  required String oid,
}) async {
  final objectReadResult = await readObject(
    fs: fs,
    cache: cache,
    gitdir: gitdir,
    oid: oid,
    format: 'content',
  );

  // Assuming objectReadResult is a class/map with 'type' and 'object' (content) properties
  final String type = objectReadResult.type;
  final dynamic objectContent =
      objectReadResult.object; // Uint8List or String typically

  if (type != 'tag') {
    throw ObjectTypeError(oid: oid, actualType: type, expectedType: 'tag');
  }

  // GitAnnotatedTag.from expects the raw tag object content (Buffer in JS)
  // Ensure objectContent is of the correct type (e.g., Uint8List or String)
  final tagModel = GitAnnotatedTag.from(objectContent);

  // tagModel will have parse() and payload() methods
  final parsedTag = tagModel.parse(); // This should return ParsedTagObject
  final payloadString = tagModel
      .payload(); // This should return the PGP payload string

  return ReadTagResult(oid: oid, tag: parsedTag, payload: payloadString);
}
