import 'failure.dart';

/// Sealed Result monad for explicit functional error handling
sealed class Result<T> {
  const Result();

  /// Create a successful result
  const factory Result.success(T data) = Success<T>;

  /// Create an error result
  const factory Result.error(Failure failure) = Error<T>;

  /// Returns true if this is a [Success]
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is an [Error]
  bool get isError => this is Error<T>;

  /// Extracts data if successful, null otherwise
  T? get dataOrNull => switch (this) {
        Success(data: final d) => d,
        Error() => null,
      };

  /// Extracts failure if error, null otherwise
  Failure? get failureOrNull => switch (this) {
        Success() => null,
        Error(failure: final f) => f,
      };

  /// Pattern match over success and error branches
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  }) =>
      switch (this) {
        Success(data: final d) => success(d),
        Error(failure: final f) => error(f),
      };

  /// Map inner data to a new type
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success(data: final d) => Result.success(transform(d)),
        Error(failure: final f) => Result.error(f),
      };

  /// FlatMap to another result
  Result<R> flatMap<R>(Result<R> Function(T data) transform) => switch (this) {
        Success(data: final d) => transform(d),
        Error(failure: final f) => Result.error(f),
      };
}

/// Represents a successful computation returning [data]
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Result.success($data)';
}

/// Represents a failed computation returning a [Failure]
class Error<T> extends Result<T> {
  final Failure failure;

  const Error(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Error<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.error($failure)';
}
