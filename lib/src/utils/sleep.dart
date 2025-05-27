import 'dart:async';

/// Pauses execution for the given number of milliseconds.
Future<void> sleep(int ms) {
  return Future.delayed(Duration(milliseconds: ms));
}