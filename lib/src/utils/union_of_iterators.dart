import '../models/running_minimum.dart';

Stream<List<String?>> unionOfIterators(List<Iterator<String>> sets) async* {
  final min = RunningMinimum();
  String? minimum;
  final heads = List<String?>.filled(sets.length, null);
  final numsets = sets.length;

  for (var i = 0; i < numsets; i++) {
    if (sets[i].moveNext()) {
      heads[i] = sets[i].current;
      if (heads[i] != null) {
        min.consider(heads[i]!);
      }
    } else {
      heads[i] = null; // Iterator is done
    }
  }

  if (min.value == null) {
    return;
  }

  while (true) {
    final result = List<String?>.filled(numsets, null);
    minimum = min.value;
    min.reset();

    for (var i = 0; i < numsets; i++) {
      if (heads[i] != null && heads[i] == minimum) {
        result[i] = heads[i];
        if (sets[i].moveNext()) {
          heads[i] = sets[i].current;
        } else {
          heads[i] = null; // Iterator is done
        }
      } else {
        result[i] = null;
      }
      if (heads[i] != null) {
        min.consider(heads[i]!);
      }
    }
    yield result;
    if (min.value == null) {
      return;
    }
  }
}
