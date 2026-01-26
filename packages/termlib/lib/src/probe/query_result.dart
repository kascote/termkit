import 'package:meta/meta.dart';

/// Reason why a query result is unavailable.
enum UnavailableReason {
  /// No response within timeout
  timeout,

  /// Terminal explicitly said no (rare)
  unsupported,

  /// Response couldn't be parsed
  parseError,

  /// Query skipped via skip parameter
  skipped,
}

/// Result wrapper for terminal capability queries.
///
/// Three states: [Pending] (not yet queried), [Supported] (value available),
/// [Unavailable] (failed with reason).
@immutable
sealed class QueryResult<T> {
  /// Creates a query result.
  const QueryResult();
}

/// Query not yet completed.
@immutable
class Pending<T> extends QueryResult<T> {
  /// Creates a pending result.
  const Pending();

  @override
  String toString() => 'Pending<$T>()';
}

/// Query succeeded, value available.
@immutable
class Supported<T> extends QueryResult<T> {
  /// The query result value.
  final T value;

  /// Creates a supported result with [value].
  const Supported(this.value);

  @override
  String toString() => 'Supported<$T>($value)';

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Supported<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

/// Query failed or was skipped.
@immutable
class Unavailable<T> extends QueryResult<T> {
  /// The reason why the query is unavailable.
  final UnavailableReason reason;

  /// Creates an unavailable result with [reason].
  const Unavailable(this.reason);

  @override
  String toString() => 'Unavailable<$T>($reason)';

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Unavailable<T> && other.reason == reason);

  @override
  int get hashCode => reason.hashCode;
}
