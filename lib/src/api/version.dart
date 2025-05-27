import '../utils/pkg.dart';

/// Return the version number of isomorphic-git
///
/// I don't know why you might need this. I added it just so I could check that I was getting
/// the correct version of the library and not a cached version.
///
/// @returns {string} the version string taken from package.json at publication time
///
/// @example
/// console.log(version());
///
String version() {
  try {
    return pkgVersion; // Assuming pkg.version is exposed as pkgVersion from the Dart package
  } catch (err) {
    // In Dart, it's more common to let exceptions propagate or handle them specifically.
    // Adding a caller property to an error is not standard Dart practice.
    // If you need to track where the error originated, you might need a custom error class
    // or pass that information explicitly.
    rethrow;
  }
}
