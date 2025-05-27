import 'dart:convert';
import 'dart:typed_data';

import '../errors/internal_error.dart'; // Assuming this will be created
import '../utils/author_utils.dart'; // Assuming for formatAuthor and parseAuthor
import '../utils/string_utils.dart'; // Assuming for normalizeNewlines

// Placeholder for a PGP signing function type
typedef SignFunction = Future<({String signature})> Function({
  required String payload,
  required String secretKey,
});

class GitAnnotatedTag {
  late String _tag;

  GitAnnotatedTag(dynamic tag) {
    if (tag is String) {
      _tag = tag;
    } else if (tag is Uint8List) {
      _tag = utf8.decode(tag);
    } else if (tag is Map<String, dynamic>) {
      _tag = GitAnnotatedTag.render(tag.cast<String, dynamic>());
    } else {
      throw InternalError('Invalid type passed to GitAnnotatedTag constructor');
    }
  }

  static GitAnnotatedTag from(dynamic tag) {
    return GitAnnotatedTag(tag);
  }

  static String render(Map<String, dynamic> obj) {
    // Ensure all required fields are present and are of correct type
    final object = obj['object'] as String? ?? '';
    final type = obj['type'] as String? ?? '';
    final tag = obj['tag'] as String? ?? '';
    final tagger = obj['tagger']; // Can be Map or Author object
    final message = obj['message'] as String? ?? '';
    final gpgsig = obj['gpgsig'] as String? ?? '';

    String taggerString;
    if (tagger is Map) {
        taggerString = formatAuthor(tagger.cast<String, dynamic>());
    } else if (tagger is Author) { // Assuming an Author class exists
        taggerString = formatAuthor(tagger.toMap());
    } else {
        taggerString = ''; // Or handle as an error
    }

    return 'object $object\n'
        'type $type\n'
        'tag $tag\n'
        'tagger $taggerString\n\n'
        '$message\n'
        '${gpgsig.isNotEmpty ? gpgsig : ''}';
  }

  String justHeaders() {
    final index = _tag.indexOf('\n\n');
    if (index == -1) return _tag; // Or handle as an error if format is unexpected
    return _tag.substring(0, index);
  }

  String message() {
    final tag = withoutSignature();
    final index = tag.indexOf('\n\n');
    if (index == -1 || index + 2 >= tag.length) return ''; // Or handle error
    return tag.substring(index + 2);
  }

  Map<String, dynamic> parse() {
    return {
      ...headers(),
      'message': message(),
      'gpgsig': gpgsig(),
    };
  }

  String renderTag() {
    return _tag;
  }

  Map<String, dynamic> headers() {
    final headerSection = justHeaders();
    final lines = headerSection.split('\n');
    final List<String> processedHeaders = [];

    for (final h in lines) {
      if (h.startsWith(' ')) {
        if (processedHeaders.isNotEmpty) {
          processedHeaders[processedHeaders.length - 1] += '\n${h.substring(1)}';
        } else {
          // This case (a continuation line at the very beginning) should ideally not happen in valid git tag formats.
          // Handle as an error or ignore, depending on strictness.
          processedHeaders.add(h.substring(1)); 
        }
      } else {
        processedHeaders.add(h);
      }
    }

    final Map<String, dynamic> obj = {};
    for (final h in processedHeaders) {
      final firstSpace = h.indexOf(' ');
      if (firstSpace == -1) continue; // Skip malformed headers

      final key = h.substring(0, firstSpace);
      final value = h.substring(firstSpace + 1);

      if (obj.containsKey(key)) {
        final existing = obj[key];
        if (existing is List<String>) {
          existing.add(value);
        } else {
          obj[key] = [existing as String, value];
        }
      } else {
        obj[key] = value;
      }
    }

    if (obj.containsKey('tagger') && obj['tagger'] is String) {
      obj['tagger'] = parseAuthor(obj['tagger'] as String);
    }
    if (obj.containsKey('committer') && obj['committer'] is String) {
      obj['committer'] = parseAuthor(obj['committer'] as String);
    }
    return obj;
  }

  String withoutSignature() {
    final tag = normalizeNewlines(_tag);
    final pgpSignatureStartIndex = tag.indexOf('\n-----BEGIN PGP SIGNATURE-----');
    if (pgpSignatureStartIndex == -1) return tag;
    return tag.substring(0, pgpSignatureStartIndex);
  }

  String? gpgsig() {
    final pgpSignatureStartIndex = _tag.indexOf('-----BEGIN PGP SIGNATURE-----');
    if (pgpSignatureStartIndex == -1) return null;

    final pgpSignatureEndIndex = _tag.indexOf('-----END PGP SIGNATURE-----', pgpSignatureStartIndex);
    if (pgpSignatureEndIndex == -1) return null; // Malformed or incomplete signature

    final signature = _tag.substring(
      pgpSignatureStartIndex,
      pgpSignatureEndIndex + '-----END PGP SIGNATURE-----'.length,
    );
    return normalizeNewlines(signature);
  }

  String payload() {
    return '${withoutSignature()}\n';
  }

  Uint8List toObject() {
    return utf8.encode(_tag);
  }

  static Future<GitAnnotatedTag> signTag(
    GitAnnotatedTag tag,
    SignFunction signFunction, // Using the typedef for the signing function
    String secretKey,
  ) async {
    final payloadToSign = tag.payload();
    final result = await signFunction(payload: payloadToSign, secretKey: secretKey);
    String signature = result.signature;
    
    signature = normalizeNewlines(signature);
    final signedTagString = payloadToSign + signature;
    return GitAnnotatedTag.from(signedTagString);
  }
}

// Assuming an Author class/structure exists, possibly like this:
// class Author {
//   String name;
//   String email;
//   int timestamp;
//   int timezoneOffset;
//   Author({required this.name, required this.email, required this.timestamp, required this.timezoneOffset});
//   Map<String, dynamic> toMap() => {'name': name, 'email': email, 'timestamp': timestamp, 'timezoneOffset': timezoneOffset};
// }