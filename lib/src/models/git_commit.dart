import 'dart:convert';
import 'dart:typed_data';

import '../errors/internal_error.dart'; // Placeholder
import '../utils/author_utils.dart'; // Placeholder for formatAuthor, parseAuthor
import '../utils/string_utils.dart'; // Placeholder for normalizeNewlines, indent, outdent

// Placeholder for a PGP signing function type
typedef SignFunction = Future<({String signature})> Function({
  required String payload,
  required String secretKey,
});

// Assuming an Author class/structure exists, possibly like this:
// class Author {
//   String name;
//   String email;
//   int timestamp;
//   int timezoneOffset;
//   Author({required this.name, required this.email, required this.timestamp, required this.timezoneOffset});
//   Map<String, dynamic> toMap() => {'name': name, 'email': email, 'timestamp': timestamp, 'timezoneOffset': timezoneOffset};
//   static Author fromMap(Map<String, dynamic> map) => Author(name: map['name'], email: map['email'], timestamp: map['timestamp'], timezoneOffset: map['timezoneOffset']);
// }

class GitCommit {
  late String _commit;

  GitCommit(dynamic commit) {
    if (commit is String) {
      _commit = commit;
    } else if (commit is Uint8List) {
      _commit = utf8.decode(commit);
    } else if (commit is Map<String, dynamic>) {
      _commit = GitCommit.render(commit.cast<String, dynamic>());
    } else {
      throw InternalError('Invalid type passed to GitCommit constructor');
    }
  }

  static GitCommit fromPayloadSignature({
    required String payload,
    required String signature,
  }) {
    final headers = GitCommit.justHeaders(payload);
    final message = GitCommit.justMessage(payload);
    // Ensure signature is indented correctly, normalizeNewlines might be needed for signature too
    final commitStr = normalizeNewlines(
        '$headers\ngpgsig${indent(normalizeNewlines(signature))}\n$message');
    return GitCommit(commitStr);
  }

  static GitCommit from(dynamic commit) {
    return GitCommit(commit);
  }

  Uint8List toObject() {
    return utf8.encode(_commit);
  }

  Map<String, dynamic> headers() {
    return parseHeaders();
  }

  String message() {
    return GitCommit.justMessage(_commit);
  }

  Map<String, dynamic> parse() {
    return {
      'message': message(),
      ...headers(),
    };
  }

  static String justMessage(String commit) {
    final index = commit.indexOf('\n\n');
    if (index == -1 || index + 2 >= commit.length) return '';
    return normalizeNewlines(commit.substring(index + 2));
  }

  static String justHeaders(String commit) {
    final index = commit.indexOf('\n\n');
    if (index == -1) return commit; // Or handle as error
    return commit.substring(0, index);
  }

  Map<String, dynamic> parseHeaders() {
    final headerSection = GitCommit.justHeaders(_commit);
    final lines = headerSection.split('\n');
    final List<String> processedHeaders = [];

    for (final h in lines) {
      if (h.startsWith(' ')) {
        if (processedHeaders.isNotEmpty) {
          processedHeaders[processedHeaders.length - 1] += '\n${h.substring(1)}';
        } else {
          processedHeaders.add(h.substring(1));
        }
      } else {
        processedHeaders.add(h);
      }
    }

    final Map<String, dynamic> obj = {
      'parent': <String>[], // Initialize parent as a list of strings
    };

    for (final h in processedHeaders) {
      final firstSpace = h.indexOf(' ');
      if (firstSpace == -1) continue; 

      final key = h.substring(0, firstSpace);
      final value = h.substring(firstSpace + 1);

      if (key == 'parent') {
        (obj['parent'] as List<String>).add(value);
      } else if (obj.containsKey(key)) {
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

    if (obj.containsKey('author') && obj['author'] is String) {
      obj['author'] = parseAuthor(obj['author'] as String);
    }
    if (obj.containsKey('committer') && obj['committer'] is String) {
      obj['committer'] = parseAuthor(obj['committer'] as String);
    }
    // gpgsig is handled by splitting and indenting, then re-joining.
    // If gpgsig is directly in headers (not common for parsing, but for rendering),
    // it might need special handling here if it's multi-line.
    // The JS version seems to parse gpgsig separately or assumes it's single line after 'gpgsig '.

    return obj;
  }

  static String renderHeaders(Map<String, dynamic> obj) {
    String headers = '';
    headers += 'tree ${obj['tree'] ?? '4b825dc642cb6eb9a060e54bf8d69288fbee4904'}\n'; // a null tree

    final parents = obj['parent'];
    if (parents != null) {
      if (parents is! List) {
        throw InternalError("Commit 'parent' property should be an array/List");
      }
      for (final p in parents as List<String>) {
        headers += 'parent $p\n';
      }
    }

    final author = obj['author'];
    if (author == null) throw InternalError('Author is required');
    headers += 'author ${formatAuthor(author is Author ? author.toMap() : author as Map<String,dynamic>)}\n';

    final committer = obj['committer'] ?? author;
    headers += 'committer ${formatAuthor(committer is Author ? committer.toMap() : committer as Map<String,dynamic>)}\n';

    if (obj.containsKey('gpgsig') && obj['gpgsig'] != null) {
      headers += 'gpgsig${indent(normalizeNewlines(obj['gpgsig'] as String))}';
    }
    return headers.trimRight(); // Remove trailing newline if gpgsig was last
  }

  static String render(Map<String, dynamic> obj) {
    if (!obj.containsKey('message')) throw InternalError('Message is required');
    final message = obj['message'] as String;
    // Ensure there's a newline between headers and message if headers don't end with one
    String renderedHeaders = renderHeaders(obj);
    if (!renderedHeaders.endsWith('\n') && renderedHeaders.isNotEmpty) renderedHeaders += '\n';
    return '$renderedHeaders\n${normalizeNewlines(message)}';
  }

  String renderCommit() {
    return _commit;
  }

  String withoutSignature() {
    final commit = normalizeNewlines(_commit);
    final gpgSigIndex = commit.indexOf('\ngpgsig');
    if (gpgSigIndex == -1) return commit;

    // Find the start of the message part after the signature
    // This assumes the signature block ends with '-----END PGP SIGNATURE-----\n'
    final endMarker = '-----END PGP SIGNATURE-----';
    int messageStartIndex = commit.indexOf(endMarker, gpgSigIndex);
    if (messageStartIndex != -1) {
      messageStartIndex = commit.indexOf('\n', messageStartIndex + endMarker.length);
      if (messageStartIndex != -1) {
         final headers = commit.substring(0, gpgSigIndex);
         final message = commit.substring(messageStartIndex + 1); // +1 to skip the newline itself
         return normalizeNewlines('$headers\n$message');
      }
    }
    // Fallback or error if signature block is malformed or not followed by a newline and message
    return commit; // Or throw error
  }

  String? isolateSignature() {
    final sigStartIndex = _commit.indexOf('-----BEGIN PGP SIGNATURE-----');
    if (sigStartIndex == -1) return null;

    final sigEndIndex = _commit.indexOf('-----END PGP SIGNATURE-----', sigStartIndex);
    if (sigEndIndex == -1) return null;

    final signatureBlock = _commit.substring(
      sigStartIndex,
      sigEndIndex + '-----END PGP SIGNATURE-----'.length,
    );
    // The original JS code uses outdent here. We need to ensure 'gpgsig' line is removed.
    // The signature itself is usually not indented relative to the 'gpgsig' line.
    // It's more about extracting the block that was indented after 'gpgsig '.
    // So, we find the 'gpgsig' line, then extract the indented block.
    final gpgsigLineStart = _commit.lastIndexOf('\ngpgsig', sigStartIndex);
    if (gpgsigLineStart == -1) return null; // Should not happen if sigStartIndex was found
    
    // The actual signature content starts after 'gpgsig' and the first newline of the indented block
    final actualSignatureContentStart = _commit.indexOf('\n', gpgsigLineStart + '\ngpgsig'.length) +1;
    if (actualSignatureContentStart == 0) return null; // Malformed

    final fullSignatureBlock = _commit.substring(actualSignatureContentStart, sigEndIndex + '-----END PGP SIGNATURE-----'.length);
    return outdent(fullSignatureBlock); // outdent will remove the leading space from each line
  }

  static Future<GitCommit> sign(
    GitCommit commit,
    SignFunction signFunction,
    String secretKey,
  ) async {
    final payload = commit.withoutSignature();
    // The message is part of the payload in 'withoutSignature'
    // final message = GitCommit.justMessage(commit._commit); // This would get original message
    
    final result = await signFunction(payload: payload, secretKey: secretKey);
    String signature = result.signature;
    signature = normalizeNewlines(signature);

    // Reconstruct the commit with the new signature
    // We need headers from the original (or rather, from the payload which is headers + message)
    // and the message itself.
    final headersFromPayload = GitCommit.justHeaders(payload);
    final messageFromPayload = GitCommit.justMessage(payload);

    final signedCommitStr =
        '$headersFromPayload\ngpgsig${indent(signature)}\n$messageFromPayload';
    return GitCommit.from(signedCommitStr);
  }
}