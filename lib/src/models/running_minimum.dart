class RunningMinimum<T extends Comparable<T>> {
  T? value;

  RunningMinimum();

  void consider(T? newValue) {
    if (newValue == null) return;
    if (value == null || newValue.compareTo(value!) < 0) {
      value = newValue;
    }
  }

  void reset() {
    value = null;
  }
}