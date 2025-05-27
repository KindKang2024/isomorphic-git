int compareStrings(String a, String b) {
  // Equivalent to: -(a < b) || +(a > b)
  if (a.compareTo(b) < 0) {
    return -1;
  } else if (a.compareTo(b) > 0) {
    return 1;
  }
  return 0;
}