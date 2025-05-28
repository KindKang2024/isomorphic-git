import './base_error.dart';

class AmbiguousError extends BaseError {
  final String nouns;
  final String short;
  final List<String> matches;

  AmbiguousError(this.nouns, this.short, this.matches)
      : super(message:
            'Found multiple $nouns matching "$short" (${matches.join(', ')}). Use a longer abbreviation length to disambiguate them.') {
    super.code = "AmbiguousError";
    super.data = {'nouns': nouns, 'short': short, 'matches': matches};
  }
}