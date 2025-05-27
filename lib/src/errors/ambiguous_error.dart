import './base_error.dart';

class AmbiguousError extends BaseError {
  static const String code = 'AmbiguousError';

  final String nouns;
  final String short;
  final List<String> matches;

  AmbiguousError(this.nouns, this.short, this.matches)
      : super(
            'Found multiple $nouns matching "$short" (${matches.join(', ')}). Use a longer abbreviation length to disambiguate them.') {
    super.code = code;
    super.data = {'nouns': nouns, 'short': short, 'matches': matches};
  }
}