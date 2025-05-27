import 'dart:async';
import 'dart:convert';

import '../utils/fifo.dart'; // Assuming FIFO is defined here

// Note: findSplit logic is directly incorporated into the splitLines function in Dart.

Stream<String> splitLines(Stream<List<int>> input) {
  final controller = StreamController<String>();
  String buffer = '';

  input
      .transform(utf8.decoder)
      .listen(
        (chunk) {
          buffer += chunk;
          while (true) {
            int r = buffer.indexOf('\r');
            int n = buffer.indexOf('\n');
            int splitPoint = -1;

            if (r == -1 && n == -1) {
              // No newline characters found
              break;
            } else if (r == -1) {
              // Only \n found
              splitPoint = n + 1;
            } else if (n == -1) {
              // Only \r found
              splitPoint = r + 1;
            } else if (n == r + 1) {
              // \r\n found
              splitPoint = n + 1;
            } else {
              // Both \r and \n found, take the earlier one
              splitPoint = (r < n ? r : n) + 1;
            }

            controller.add(buffer.substring(0, splitPoint));
            buffer = buffer.substring(splitPoint);
          }
        },
        onDone: () {
          if (buffer.isNotEmpty) {
            controller.add(buffer);
          }
          controller.close();
        },
        onError: (error, stackTrace) {
          controller.addError(error, stackTrace);
          controller.close();
        },
      );

  return controller.stream;
}

// Dart's Stream<String> can be used directly instead of a custom FIFO for strings.
// However, if the FIFO class has other specific behaviors from the JS version that are needed,
// it would need to be implemented.
// For the purpose of `splitLines`, a direct Stream<String> is more idiomatic in Dart.

// The `forAwait` utility from JS is analogous to how Dart streams are consumed with `await for` or `listen`.
