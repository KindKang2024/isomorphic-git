import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import '../utils/fifo.dart'; // Assuming FIFO is defined here (StreamController based)
import './git_pkt_line.dart'; // Assuming GitPktLine is defined here

class GitSideBand {
  // The 'mux' part was commented out in JS, so we'll omit it here too.

  static Map<String, StreamController<Uint8List>> demux(Stream<List<int>> inputStream) {
    final pktLineStreamReader = GitPktLine.streamReader(inputStream);

    final packetlinesController = StreamController<Uint8List>();
    final packfileController = StreamController<Uint8List>();
    final progressController = StreamController<Uint8List>();

    Future<void> process() async {
      try {
        while (true) {
          final line = await pktLineStreamReader();

          if (line == null) { // Flush packet or delim (GitPktLine.streamReader returns null for these)
            // Original JS has 'return nextBit()' which effectively continues the loop.
            // Here, we just continue to the next iteration.
            continue;
          }

          // Original JS used 'true' to signal end of stream from reader.
          // Dart's stream reader would signal end by returning null or specific value.
          // Let's assume GitPktLine.streamReader returns Uint8List(0) for clean end.
          if (line.isEmpty) { // End of stream signal from custom reader
            packetlinesController.close();
            progressController.close();
            packfileController.close();
            break; // Exit loop
          }

          if (line.isEmpty) break; // Should be handled by reader returning null or specific end signal

          final streamId = line[0];
          final payload = line.sublist(1);

          switch (streamId) {
            case 1: // pack data
              packfileController.add(payload);
              break;
            case 2: // progress message
              progressController.add(payload);
              break;
            case 3: // fatal error message
              final errorMessage = utf8.decode(payload);
              progressController.add(payload); // Send error to progress as well
              packetlinesController.close();
              progressController.close();
              packfileController.addError(Exception(errorMessage));
              packfileController.close();
              return; // Stop processing
            default: // Not part of side-band protocol, treat as raw packetline
              packetlinesController.add(line);
          }
        }
      } catch (e, s) {
        // Propagate error to streams
        if (!packetlinesController.isClosed) packetlinesController.addError(e, s);
        if (!packfileController.isClosed) packfileController.addError(e, s);
        if (!progressController.isClosed) progressController.addError(e, s);
      } finally {
        // Ensure streams are closed if not already
        if (!packetlinesController.isClosed) packetlinesController.close();
        if (!packfileController.isClosed) packfileController.close();
        if (!progressController.isClosed) progressController.close();
      }
    }

    process(); // Start processing asynchronously

    return {
      'packetlines': packetlinesController,
      'packfile': packfileController,
      'progress': progressController,
    };
  }
}