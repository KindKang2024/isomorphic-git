import 'base_error.dart';

class UnmergedPathsError extends BaseError {
  final List<String> filepaths;

  UnmergedPathsError({required this.filepaths})
    : super(
        message:
            'Modifying the index is not possible because you have unmerged files: ${filepaths.join(', ')}. Fix them up in the work tree, and then use \'git add/rm <file>...\' as appropriate to mark resolution and make a commit.',
      );

  @override
  String get code => 'UnmergedPathsError';

  @override
  Map<String, dynamic> get data => {'filepaths': filepaths};
}
