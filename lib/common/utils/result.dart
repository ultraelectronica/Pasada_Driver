/// A generic Result class for handling success and error states
sealed class Result<T> {
  const Result();
}

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

class Failure<T> extends Result<T> {
  final String message;
  final String type;
  final Exception? exception;
  const Failure({required this.message, required this.type, this.exception});
  @override
  String toString() => 'Failure(message: $message, type: $type)';
  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.message == message && other.type == type;
  @override
  int get hashCode => Object.hash(message, type);
}

extension ResultExtensions<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T? get data => switch (this) {
        Success<T>(data: final d) => d,
        Failure<T>() => null,
      };
  String? get error => switch (this) {
        Success<T>() => null,
        Failure<T>(message: final m) => m,
      };
  Result<R> map<R>(R Function(T) mapper) => switch (this) {
        Success<T>(data: final d) => Success(mapper(d)),
        Failure<T>(message: final m, type: final t, exception: final e) =>
          Failure(message: m, type: t, exception: e),
      };
  R when<R>(
          {required R Function(T data) success,
          required R Function(String message, String type) failure}) =>
      switch (this) {
        Success<T>(data: final d) => success(d),
        Failure<T>(message: final m, type: final t) => failure(m, t),
      };
}
