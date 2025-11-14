/// Base class for all events.
base class Event {
  /// Constructor
  const Event();
}

/// User-generated input events (keyboard, mouse, paste).
///
/// Use [InputEvent] for type-safe filtering of user input:
/// ```dart
/// final inputs = events.whereType<InputEvent>();
/// ```
abstract base class InputEvent extends Event {
  /// Constructor
  const InputEvent();
}

/// Terminal responses to queries (cursor position, colors, device attributes).
///
/// Use [ResponseEvent] for type-safe filtering of terminal responses:
/// ```dart
/// final responses = events.whereType<ResponseEvent>();
/// ```
abstract base class ResponseEvent extends Event {
  /// Constructor
  const ResponseEvent();
}

/// Parser/engine error events for malformed or invalid sequences.
///
/// Use [ErrorEvent] for type-safe filtering of parser errors:
/// ```dart
/// final errors = events.whereType<ErrorEvent>();
/// ```
abstract base class ErrorEvent extends Event {
  /// Constructor
  const ErrorEvent();
}

/// Internal parser events (no-op, unknown sequences).
///
/// Typically not used by applications directly.
abstract base class InternalEvent extends Event {
  /// Constructor
  const InternalEvent();
}
