class BaseError implements Exception {
  String caller = '';
  String? code;
  dynamic data;
  String message;
  StackTrace? stackTrace;

  BaseError({required this.message});

  Map<String, dynamic> toJson() => {
        'code': code,
        'data': data,
        'caller': caller,
        'message': message,
        // Dart's Error.stackTrace is not directly serializable like JS this.stack
        // You might need a custom way to handle or represent stack traces if serialization is key.
        'stackTrace': stackTrace?.toString(),
      };

  static BaseError fromJson(Map<String, dynamic> json) {
    final e = BaseError(message:json['message'] as String);
    e.code = json['code'] as String?;
    e.data = json['data'];
    e.caller = json['caller'] as String;
    // Deserialize stackTrace if needed, though direct mapping from string might be complex
    return e;
  }

  bool get isIsomorphicGitError => true;

  @override
  String toString() {
    String result = 'BaseError: $message';
    if (code != null) {
      result += ' (code: $code)';
    }
    if (caller.isNotEmpty) {
      result += ' (caller: $caller)';
    }
    return result;
  }
}