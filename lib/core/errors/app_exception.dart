/// Base type for errors raised inside QuickNotes.
///
/// The UI layer catches these and shows user-friendly messages, while the
/// [cause] and [stackTrace] are kept for debugging.
class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Raised when a SQLite operation fails.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause, super.stackTrace});

  @override
  String toString() => 'DatabaseException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Raised when user-supplied input fails validation.
class ValidationException extends AppException {
  const ValidationException(super.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Raised when a requested record does not exist.
class NotFoundException extends AppException {
  const NotFoundException(super.message);

  @override
  String toString() => 'NotFoundException: $message';
}
