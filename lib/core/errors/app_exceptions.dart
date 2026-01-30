/// Base application exception
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Validation-related exceptions
class ValidationException extends AppException {
  ValidationException(super.message, {super.code});

  @override
  String toString() =>
      'ValidationException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Balance/financial operation exceptions
class BalanceException extends AppException {
  BalanceException(super.message, {super.code});

  @override
  String toString() =>
      'BalanceException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Permission/authorization exceptions
class PermissionException extends AppException {
  PermissionException(super.message, {super.code});

  @override
  String toString() =>
      'PermissionException: $message${code != null ? ' (Code: $code)' : ''}';
}
