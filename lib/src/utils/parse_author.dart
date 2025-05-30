class Author {
  final String name;
  final String email;
  final int timestamp;
  final int timezoneOffset;

  Author({
    required this.name,
    required this.email,
    required this.timestamp,
    required this.timezoneOffset,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'timestamp': timestamp,
      'timezoneOffset': timezoneOffset,
    };
  }

  @override
  String toString() {
    return 'Author{name: $name, email: $email, timestamp: $timestamp, timezoneOffset: $timezoneOffset}';
  }
}

Author parseAuthor(String authorLine) {
  final match = RegExp(
    r'^(.*) <(.*)> (\d+) ([+-]\d{4})$',
  ).firstMatch(authorLine);

  if (match == null) {
    throw FormatException('Invalid author string format', authorLine);
  }

  final name = match.group(1)!;
  final email = match.group(2)!;
  final timestamp = int.parse(match.group(3)!);
  final offsetString = match.group(4)!;

  return Author(
    name: name,
    email: email,
    timestamp: timestamp,
    timezoneOffset: parseTimezoneOffset(offsetString),
  );
}

int parseTimezoneOffset(String offset) {
  final match = RegExp(r'([+-])(\d\d)(\d\d)').firstMatch(offset);

  if (match == null) {
    throw FormatException('Invalid timezone offset format', offset);
  }

  final signStr = match.group(1)!;
  final hoursStr = match.group(2)!;
  final minutesStr = match.group(3)!;

  final sign = (signStr == '+') ? 1 : -1;
  final hours = int.parse(hoursStr);
  final minutes = int.parse(minutesStr);

  final totalMinutes = sign * (hours * 60 + minutes);
  return negateExceptForZero(totalMinutes);
}

int negateExceptForZero(int n) {
  return n == 0 ? 0 : -n;
}
