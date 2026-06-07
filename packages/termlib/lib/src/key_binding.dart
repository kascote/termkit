import 'package:termparser/termparser_events.dart' show KeyEvent, KeyEventType;

/// Exception thrown when an invalid key spec is provided.
class InvalidKeySpecException implements Exception {
  /// The invalid key spec.
  final String key;

  /// Creates an InvalidKeySpecException.
  InvalidKeySpecException(this.key);

  @override
  String toString() => 'InvalidKeySpecException: "$key"';
}

/// Maps key specs to actions of type [A].
///
/// Key specs use the [KeyEvent.fromString] grammar (e.g. `'ctrl+a'`,
/// `'enter'`, `'shift+ctrl+enter'`). Multiple specs may map to the
/// same action (aliases).
///
/// ```dart
/// final binding = KeyBinding<AppAction>()
///   ..map(['ctrl+q', 'escape'], AppAction.quit)
///   ..map(['ctrl+s'], AppAction.save);
///
/// final action = binding.resolve(keyEvent);
/// if (action != null) {
///   // handle action
/// }
/// ```
///
/// Press and auto-repeat events are resolved (a held key keeps firing its
/// action); only `KeyEventType.keyRelease` events return `null`.
class KeyBinding<A> {
  final Map<String, A> _bindings = {};

  /// Maps one or more key specs to an action.
  ///
  /// Specs are canonicalized on insertion (e.g. `'Enter'` → `'enter'`,
  /// `'shift+ctrl+a'` → `'ctrl+shift+A'`) so lookup is order- and
  /// case-independent.
  ///
  /// Silently overrides existing bindings (enables user overrides).
  /// Throws [InvalidKeySpecException] on invalid specs.
  void map(List<String> keys, A action) {
    for (final key in keys) {
      _bindings[_canonicalize(key)] = action;
    }
  }

  /// Canonicalizes a spec via `KeyEvent.fromString(...).toSpec()`.
  /// Throws [InvalidKeySpecException] if the spec is invalid.
  static String _canonicalize(String key) {
    try {
      return KeyEvent.fromString(key).toSpec();
      // KeyEvent.fromString throws ArgumentError for invalid specs; translate to our own exception.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw InvalidKeySpecException(key);
    }
  }

  /// Returns true if [key] is a valid key spec.
  static bool isValidKey(String key) {
    try {
      KeyEvent.fromString(key);
      return true;
      // KeyEvent.fromString throws ArgumentError for invalid specs
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return false;
    }
  }

  /// Validates key spec for config loading.
  /// Throws [InvalidKeySpecException] if invalid.
  static void validateKey(String key) {
    if (!isValidKey(key)) throw InvalidKeySpecException(key);
  }

  /// Resolves a [KeyEvent] to an action, or `null` if not bound.
  ///
  /// Matches press and auto-repeat events (so a held key keeps firing its
  /// action); release events return `null`. Callers that need a once-per-press
  /// action can filter [KeyEvent.eventType] themselves before calling.
  A? resolve(KeyEvent event) {
    if (event.eventType == KeyEventType.keyRelease) return null;
    return _bindings[event.toSpec()];
  }

  /// Returns all keys bound to [action] (for help screens).
  List<String> keysFor(A action) => _bindings.entries.where((e) => e.value == action).map((e) => e.key).toList();

  /// Adds all bindings from [other], overriding on conflict.
  void addAll(KeyBinding<A> other) {
    _bindings.addAll(other._bindings);
  }

  /// Removes binding for [key]. Spec is canonicalized before lookup.
  void remove(String key) {
    _bindings.remove(_canonicalize(key));
  }

  /// Removes all bindings for [action].
  void unbind(A action) {
    _bindings.removeWhere((_, v) => v == action);
  }

  /// Removes all bindings.
  void clear() {
    _bindings.clear();
  }

  /// Creates a copy of this binding.
  KeyBinding<A> copy() => KeyBinding<A>()..addAll(this);

  /// Returns bindings grouped by action (for config export).
  /// Actions with no bindings are omitted.
  Map<A, List<String>> toGroupedMap() {
    final result = <A, List<String>>{};
    for (final entry in _bindings.entries) {
      (result[entry.value] ??= []).add(entry.key);
    }
    return result;
  }
}
