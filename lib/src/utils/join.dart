import 'package:path/path.dart' as p;

// Joins path segments. Accepts either multiple string arguments or a single list of strings.
String join(
  dynamic firstPartOrList, [
  String? secondPart,
  String? thirdPart,
  String? fourthPart,
  String? fifthPart,
]) {
  if (firstPartOrList is List<String>) {
    return p.joinAll(firstPartOrList);
  }
  final parts = <String>[firstPartOrList as String];
  if (secondPart != null) parts.add(secondPart);
  if (thirdPart != null) parts.add(thirdPart);
  if (fourthPart != null) parts.add(fourthPart);
  if (fifthPart != null) parts.add(fifthPart); // Add more if needed
  return p.joinAll(parts);
}
