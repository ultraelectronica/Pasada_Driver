/// A generic Result class for handling success and error states
sealed class Result<T> {
  const Result();
}

/// Represents a successful result
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  String toString() => 'Success(data: $data)';

  @override
  bool operator ==(Object other) => other is Success<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;
}

/// Represents a failed result
class Failure<T> extends Result<T> {
  final String message;
  final String type;
  final Exception? exception;

  const Failure({
    required this.message,
    required this.type,
    this.exception,
  });

  @override
  String toString() => 'Failure(message: $message, type: $type)';

  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.message == message && other.type == type;

  @override
  int get hashCode => Object.hash(message, type);
}

/// Extension methods for Result
extension ResultExtensions<T> on Result<T> {
  /// Returns true if this is a success result
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result
  bool get isFailure => this is Failure<T>;

  /// Gets the data if success, null otherwise
  T? get data => switch (this) {
        Success<T>(data: final data) => data,
        Failure<T>() => null,
      };

  /// Gets the error message if failure, null otherwise
  String? get error => switch (this) {
        Success<T>() => null,
        Failure<T>(message: final message) => message,
      };

  /// Maps the success value to a new type
  Result<R> map<R>(R Function(T) mapper) => switch (this) {
        Success<T>(data: final data) => Success(mapper(data)),
        Failure<T>(
          message: final message,
          type: final type,
          exception: final exception
        ) =>
          Failure(message: message, type: type, exception: exception),
      };

  /// Handles both success and failure cases
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, String type) failure,
  }) =>
      switch (this) {
        Success<T>(data: final data) => success(data),
        Failure<T>(message: final message, type: final type) =>
          failure(message, type),
      };
}
