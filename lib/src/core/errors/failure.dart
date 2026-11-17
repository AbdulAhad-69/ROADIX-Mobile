/// Domain error and failure abstractions
sealed class Failure {
  final String message;
  final String? code;
  final Object? cause;

  const Failure(this.message, {this.code, this.cause});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

/// Network connectivity or transport failures
class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.code = 'NETWORK_ERROR',
    super.cause,
  });
}

/// Authentication and authorization failures
class AuthFailure extends Failure {
  const AuthFailure(
    super.message, {
    super.code = 'AUTH_ERROR',
    super.cause,
  });
}

/// Location, GPS, or device permission failures
class PermissionFailure extends Failure {
  const PermissionFailure(
    super.message, {
    super.code = 'PERMISSION_DENIED',
    super.cause,
  });
}

/// Triage input or validation failures
class TriageFailure extends Failure {
  const TriageFailure(
    super.message, {
    super.code = 'TRIAGE_INVALID',
    super.cause,
  });
}

/// Supabase or external server-side failures
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(
    super.message, {
    this.statusCode,
    super.code = 'SERVER_ERROR',
    super.cause,
  });
}

/// Local storage or cache failures
class CacheFailure extends Failure {
  const CacheFailure(
    super.message, {
    super.code = 'CACHE_ERROR',
    super.cause,
  });
}
