String formatAuthor(Map<String, dynamic> author) {
  final String name = author['name'] as String;
  final String email = author['email'] as String;
  final int timestamp = author['timestamp'] as int;
  final int timezoneOffset = author['timezoneOffset'] as int;
  
  String tz = formatTimezoneOffset(timezoneOffset);
  return '$name <$email> $timestamp $tz';
}

String formatTimezoneOffset(int minutes) {
  int sign = simpleSign(negateExceptForZero(minutes));
  int absMinutes = minutes.abs();
  int hours = absMinutes ~/ 60;
  int mins = absMinutes % 60;
  String strHours = hours.toString().padLeft(2, '0');
  String strMinutes = mins.toString().padLeft(2, '0');
  return (sign == -1 ? '-' : '+') + strHours + strMinutes;
}

int simpleSign(int n) {
  if (n == 0) {
    // Dart does not distinguish -0, so always return 1 for 0
    return 1;
  }
  return n < 0 ? -1 : 1;
}

int negateExceptForZero(int n) {
  return n == 0 ? n : -n;
}
