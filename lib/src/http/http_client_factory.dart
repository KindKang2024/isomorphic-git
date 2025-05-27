// Export the interface and data classes so users can type hint
export './http_client_interface.dart';

// Conditionally export the getHttpClient factory from the correct implementation
export './stub/index.dart' // Stub for unsupported platforms
    if (dart.library.io) './node/index.dart' // VM/Node.js
    if (dart.library.html) './web/index.dart'; // Web
