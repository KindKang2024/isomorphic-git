import './base_error.dart';

class AlreadyExistsError extends BaseError {

  final String noun;
  final String where;
  final bool canForce;

  AlreadyExistsError(this.noun, this.where, {this.canForce = true})
    : super(message:
        'Failed to create $noun at $where because it already exists.${canForce ? " (Hint: use 'force: true' parameter to overwrite existing $noun.)" : ""}',
      ) {
    super.code = "AlreadyExistsError";
    super.data = {'noun': noun, 'where': where, 'canForce': canForce};
  }
}
