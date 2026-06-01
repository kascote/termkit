part of 'termlib_base.dart';

/// Identifies a terminal mode tracked by [TermModes].
enum TerminalMode {
  /// Raw input mode (termios).
  rawMode,

  /// Alternate screen buffer.
  alternateScreen,

  /// Mouse event reporting.
  mouseEvents,

  /// Keyboard enhancement (kitty protocol). Tracked as a flags value rather
  /// than a plain bool — see [TermModes.keyboardFlags].
  keyboardEnhancement,

  /// Bracketed paste mode.
  bracketedPaste,

  /// In-band window resize reporting.
  inBandResize,

  /// Unicode core mode.
  unicodeCore,

  /// Line wrapping (DECAWM). Terminals start with this ON.
  lineWrapping,

  /// Cursor visibility. Terminals start with this ON.
  cursorVisible,
}

/// Live state of each terminal mode — the source of truth for save/restore.
///
/// Immutable snapshot held in a private mutable cell on [InteractiveTerm];
/// every `enableX`/`disableX` toggle swaps the cell for an updated copy. Kept
/// separate from [TermInfo] (capability + frozen probe snapshot)
///
/// Internal representation is a private `int` bitfield, one bit per
/// [TerminalMode]. [TerminalMode.keyboardEnhancement] is the exception: it
/// carries a flags value ([keyboardFlags]) rather than a single bit, so its
/// state is derived from those flags instead of the bitfield.
@immutable
@internal
class TermModes {
  const TermModes._(this._flags, this.keyboardFlags);

  /// One bit per [TerminalMode] (`1 << mode.index`). The
  /// [TerminalMode.keyboardEnhancement] bit is unused — that mode's state lives
  /// in [keyboardFlags].
  final int _flags;

  /// The keyboard enhancement flags last applied, or null if never managed.
  /// Enhancement is considered enabled when these flags are non-zero.
  final KeyboardEnhancementFlagsEvent? keyboardFlags;

  /// Default terminal state: line wrapping and cursor visible on, rest off.
  static final TermModes initial = TermModes._(
    _maskOf(TerminalMode.lineWrapping) | _maskOf(TerminalMode.cursorVisible),
    null,
  );

  static int _maskOf(TerminalMode m) => 1 << m.index;

  /// Whether [m] is currently enabled.
  bool isEnabled(TerminalMode m) => switch (m) {
    TerminalMode.keyboardEnhancement => (keyboardFlags?.flags ?? 0) != 0,
    _ => _flags & _maskOf(m) != 0,
  };

  /// Raw input mode.
  bool get rawMode => isEnabled(TerminalMode.rawMode);

  /// Alternate screen buffer.
  bool get alternateScreen => isEnabled(TerminalMode.alternateScreen);

  /// Mouse event reporting.
  bool get mouseEvents => isEnabled(TerminalMode.mouseEvents);

  /// Keyboard enhancement (non-zero [keyboardFlags]).
  bool get keyboardEnhancement => isEnabled(TerminalMode.keyboardEnhancement);

  /// Bracketed paste mode.
  bool get bracketedPaste => isEnabled(TerminalMode.bracketedPaste);

  /// In-band window resize reporting.
  bool get inBandResize => isEnabled(TerminalMode.inBandResize);

  /// Unicode core mode.
  bool get unicodeCore => isEnabled(TerminalMode.unicodeCore);

  /// Line wrapping (DECAWM).
  bool get lineWrapping => isEnabled(TerminalMode.lineWrapping);

  /// Cursor visibility.
  bool get cursorVisible => isEnabled(TerminalMode.cursorVisible);

  /// Returns a copy with the named modes updated. A null bool leaves that mode
  /// unchanged; a null [keyboardFlags] leaves keyboard state unchanged.
  TermModes copyWith({
    bool? rawMode,
    bool? alternateScreen,
    bool? mouseEvents,
    bool? bracketedPaste,
    bool? inBandResize,
    bool? unicodeCore,
    bool? lineWrapping,
    bool? cursorVisible,
    KeyboardEnhancementFlagsEvent? keyboardFlags,
  }) {
    var f = _flags;
    f = _apply(f, TerminalMode.rawMode, rawMode);
    f = _apply(f, TerminalMode.alternateScreen, alternateScreen);
    f = _apply(f, TerminalMode.mouseEvents, mouseEvents);
    f = _apply(f, TerminalMode.bracketedPaste, bracketedPaste);
    f = _apply(f, TerminalMode.inBandResize, inBandResize);
    f = _apply(f, TerminalMode.unicodeCore, unicodeCore);
    f = _apply(f, TerminalMode.lineWrapping, lineWrapping);
    f = _apply(f, TerminalMode.cursorVisible, cursorVisible);
    return TermModes._(f, keyboardFlags ?? this.keyboardFlags);
  }

  static int _apply(int flags, TerminalMode m, bool? value) {
    if (value == null) return flags;
    return value ? flags | _maskOf(m) : flags & ~_maskOf(m);
  }

  @override
  bool operator ==(Object other) =>
      other is TermModes && other._flags == _flags && other.keyboardFlags == keyboardFlags;

  @override
  int get hashCode => Object.hash(_flags, keyboardFlags);
}
