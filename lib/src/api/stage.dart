// @ts-check
// import '../typedefs.js' // This will be handled by Dart's type system

/**
 * Get a git index Walker
 *
 * See [walk](./walk.md)
 *
 * @returns {Walker} Returns a git index `Walker`
 *
 */
export { STAGE } from '../commands/STAGE.js'; // This will be a Dart export

// In Dart, this would likely be a re-export from another file.
// Assuming STAGE is defined in ../commands/stage.dart
export '../commands/stage.dart' show STAGE; 