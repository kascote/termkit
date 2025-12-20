import 'package:meta/meta.dart';

import 'event_base.dart';
import 'key_support.dart';

/// Discriminator for KeyCode variants
enum KeyCodeKind {
  /// Named key (F1-F35, Enter, Escape, arrows, etc.)
  named,

  /// Printable character
  char,
}

/// Enum for keys with names
enum KeyCodeName {
  /// None
  none,

  /// Backspace
  backSpace,

  /// Enter
  enter,

  /// Left arrow key
  left,

  /// Right arrow key
  right,

  /// Up arrow key
  up,

  /// Down arrow key
  down,

  /// Home
  home,

  /// End
  end,

  /// Page up
  pageUp,

  /// Page down
  pageDown,

  /// Tab
  tab,

  /// Back tab
  backTab,

  /// Delete
  delete,

  /// Insert
  insert,

  /// Escape
  escape,

  /// CapsLock
  capsLock,

  /// ScrollLock
  scrollLock,

  /// NumLock
  numLock,

  /// PrintScreen
  printScreen,

  /// Pause
  pause,

  /// Menu
  menu,

  /// KeyPad Begin
  keypadBegin,

  /// F1
  f1,

  /// F2
  f2,

  /// F3
  f3,

  /// F4
  f4,

  /// F5
  f5,

  /// F6
  f6,

  /// F7
  f7,

  /// F8
  f8,

  /// F9
  f9,

  /// F10
  f10,

  /// F11
  f11,

  /// F12
  f12,

  /// F13
  f13,

  /// F14
  f14,

  /// F15
  f15,

  /// F16
  f16,

  /// F17
  f17,

  /// F18
  f18,

  /// F19
  f19,

  /// F20
  f20,

  /// F21
  f21,

  /// F22
  f22,

  /// F23
  f23,

  /// F24
  f24,

  /// F25
  f25,

  /// F26
  f26,

  /// F27
  f27,

  /// F28
  f28,

  /// F29
  f29,

  /// F30
  f30,

  /// F31
  f31,

  /// F32
  f32,

  /// F33
  f33,

  /// F34
  f34,

  /// F35
  f35,

  /// Play media key.
  play,

  /// Play/Pause media key.
  playPause,

  /// Reverse media key.
  reverse,

  /// Stop media key.
  stop,

  /// Fast-forward media key.
  fastForward,

  /// Rewind media key.
  rewind,

  /// Next-track media key.
  trackNext,

  /// Previous-track media key.
  trackPrevious,

  /// Record media key.
  record,

  /// Lower-volume media key.
  lowerVolume,

  /// Raise-volume media key.
  raiseVolume,

  /// Mute media key.
  muteVolume,

  /// Left Shift key
  leftShift,

  /// Left Control key
  leftCtrl,

  /// Left Alt key
  leftAlt,

  /// Left Super key
  leftSuper,

  /// Left Hyper key
  leftHyper,

  /// Left Meta key
  leftMeta,

  /// Right Shift key
  rightShift,

  /// Right Control key
  rightCtrl,

  /// Right Alt key
  rightAlt,

  /// Right Super key
  rightSuper,

  /// Right Hyper key
  rightHyper,

  /// Right Meta key
  rightMeta,

  /// ISO Level 3 Shift key
  isoLevel3Shift,

  /// ISO Level 5 Shift key
  isoLevel5Shift,
}

/// Enum for Key Events Types
enum KeyEventType {
  /// Key press event.
  keyPress,

  /// Key repeat event.
  keyRepeat,

  /// Key release event.
  keyRelease,
}

/// Represents a key pressed on the keyboard.
/// This class is used for the legacy key events as well the enhanced key events.
/// used on the Kitty protocol.
///
/// **Note:** need to have KeyboardEnhancementFlags.disambiguateEscapeCodes enabled
/// to identify some keys as media keys, leftCtrl, etc.
///
/// ref: https://sw.kovidgoyal.net/kitty/keyboard-protocol/
@immutable
class KeyCode {
  /// Discriminator indicating which type of key this represents
  final KeyCodeKind kind;

  /// Contains the name of the key if is a named key (enter, esc, pgUp, etc).
  /// Only populated when kind == KeyCodeKind.named
  final KeyCodeName name;

  /// Contains the character of the key if is a printable character.
  /// Only populated when kind == KeyCodeKind.char
  final String char;

  /// Base layout key
  ///
  /// From Kitty documentation:
  /// The base layout key is the key corresponding to the physical key in the
  /// standard PC-101 key layout. So for example, if the user is using a
  /// Cyrillic keyboard with a Cyrillic keyboard layout pressing the ctrl+С key
  /// will be ctrl+c in the standard layout. So the terminal should send the
  /// base layout key as 99 corresponding to the c key.
  final int baseLayoutKey;

  /// Private constructor
  const KeyCode._({
    required this.kind,
    this.name = KeyCodeName.none,
    this.char = '',
    this.baseLayoutKey = 0,
  });

  /// Constructs a named key (F1-F35, Enter, Escape, arrows, etc.)
  const KeyCode.named(KeyCodeName name, {int baseLayoutKey = 0})
    : this._(
        kind: KeyCodeKind.named,
        name: name,
        baseLayoutKey: baseLayoutKey,
      );

  /// Constructs a character key
  const KeyCode.char(String char, {int baseLayoutKey = 0})
    : this._(
        kind: KeyCodeKind.char,
        char: char,
        baseLayoutKey: baseLayoutKey,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyCode &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          name == other.name &&
          char == other.char &&
          baseLayoutKey == other.baseLayoutKey;

  @override
  int get hashCode => Object.hash(kind, name, char, baseLayoutKey);

  /// Create a new instance of [KeyCode] with the given parameters.
  KeyCode copyWith({
    KeyCodeKind? kind,
    KeyCodeName? name,
    String? char,
    int? baseLayoutKey,
  }) {
    return KeyCode._(
      kind: kind ?? this.kind,
      name: name ?? this.name,
      char: char ?? this.char,
      baseLayoutKey: baseLayoutKey ?? this.baseLayoutKey,
    );
  }

  @override
  String toString() {
    return 'KeyCode{kind: $kind, name: $name, char: $char, baseLayoutKey: $baseLayoutKey}';
  }
}

/// Represent a Key event.
@immutable
final class KeyEvent extends InputEvent {
  /// The key code.
  final KeyCode code;

  /// The key modifiers that could have been pressed.
  final KeyModifiers modifiers;

  /// The type of the event.
  final KeyEventType eventType;

  /// Constructs a new instance of [KeyEvent].
  const KeyEvent(
    this.code, {
    this.modifiers = KeyModifiers.none,
    this.eventType = KeyEventType.keyPress,
  });

  /// Parses a key specification string into a [KeyEvent].
  ///
  /// Supports both generic and specific modifier syntax:
  /// - 'a' → single character key
  /// - 'enter' → named key (use exact enum names)
  /// - 'ctrl+a' → modifier + key
  /// - 'shift+ctrl+enter' → multiple modifiers
  /// - 'play' → media key (use exact enum names)
  /// - 'ctrl+raiseVolume' → media key with modifier
  /// - 'leftCtrl' → named modifier key itself
  ///
  /// Key names are case-insensitive and match the enum names from
  /// [KeyCodeName].
  ///
  /// Throws [ArgumentError] if the specification is invalid.
  factory KeyEvent.fromString(String spec) {
    if (spec.isEmpty) {
      throw ArgumentError('Key specification cannot be empty');
    }

    final parts = spec.split('+');
    final keyPart = parts.last;
    final modifierParts = parts.length > 1 ? parts.sublist(0, parts.length - 1) : [parts[0]];

    var modifierMask = KeyModifiers.none;

    for (final mod in modifierParts) {
      final genericMod = _parseGenericModifier(mod);
      if (genericMod != null) {
        modifierMask |= genericMod;
        continue;
      }

      if (parts.length > 1 && genericMod == null) {
        throw ArgumentError('Unknown modifier: $mod');
      }
    }

    return KeyEvent(
      _parseKey(keyPart),
      modifiers: modifierMask,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyEvent &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          modifiers == other.modifiers &&
          eventType == other.eventType;

  @override
  int get hashCode => Object.hash(code, modifiers, eventType);

  /// Creates a copy of this [KeyEvent] with the given fields replaced.
  KeyEvent copyWith({
    KeyCode? code,
    KeyModifiers? modifiers,
    KeyEventType? eventType,
  }) {
    return KeyEvent(
      code ?? this.code,
      modifiers: modifiers ?? this.modifiers,
      eventType: eventType ?? this.eventType,
    );
  }

  /// Converts this [KeyEvent] to a specification string.
  ///
  /// This is the inverse of [KeyEvent.fromString].
  /// Outputs generic modifier names in canonical order: ctrl+alt+shift+super+hyper+meta
  ///
  /// Does not encode: eventType, baseLayoutKey, keyPad, capsLock
  ///
  /// Examples:
  /// - `KeyEvent.fromString('backSpace').toSpec()` → `'backSpace'`
  /// - `KeyEvent.fromString('ctrl+a').toSpec()` → `'ctrl+a'`
  /// - `KeyEvent(KeyCode.named(KeyCodeName.leftCtrl)).toSpec()` → `'ctrl'`
  String toSpec() {
    final parts = <String>[];
    final keySpec = _keyToSpec(code);

    for (final (modifier, name) in _modifierSpec) {
      // Skip modifier if it matches the key (e.g., leftCtrl key → 'ctrl')
      if (name == keySpec) continue;
      if (modifiers.has(modifier)) {
        parts.add(name);
      }
    }

    parts.add(keySpec);
    return parts.join('+');
  }

  @override
  String toString() {
    return 'KeyEvent{code: $code, modifiers: ${modifiers.debugInfo()}, eventType: $eventType';
  }
}

/// Canonical modifier order for toSpec output
const List<(KeyModifiers, String)> _modifierSpec = [
  (KeyModifiers.ctrl, 'ctrl'),
  (KeyModifiers.alt, 'alt'),
  (KeyModifiers.shift, 'shift'),
  (KeyModifiers.superKey, 'super'),
  (KeyModifiers.hyper, 'hyper'),
  (KeyModifiers.meta, 'meta'),
];

/// Map of generic modifier names to their bit masks
const Map<String, KeyModifiers> _genericModifiers = {
  'ctrl': KeyModifiers.ctrl,
  'alt': KeyModifiers.alt,
  'shift': KeyModifiers.shift,
  'super': KeyModifiers.superKey,
  'hyper': KeyModifiers.hyper,
  'meta': KeyModifiers.meta,
  'leftshift': KeyModifiers.shift,
  'rightshift': KeyModifiers.shift,
  'leftctrl': KeyModifiers.ctrl,
  'rightctrl': KeyModifiers.ctrl,
  'leftalt': KeyModifiers.alt,
  'rightalt': KeyModifiers.alt,
  'leftmeta': KeyModifiers.meta,
  'rightmeta': KeyModifiers.meta,
  'leftsuper': KeyModifiers.superKey,
  'rightsuper': KeyModifiers.superKey,
  'lefthyper': KeyModifiers.hyper,
  'righthyper': KeyModifiers.hyper,
};

/// Map of modifier KeyCodeName to generic name
const Map<KeyCodeName, String> _modifierKeyToGeneric = {
  KeyCodeName.leftCtrl: 'ctrl',
  KeyCodeName.rightCtrl: 'ctrl',
  KeyCodeName.leftShift: 'shift',
  KeyCodeName.rightShift: 'shift',
  KeyCodeName.leftAlt: 'alt',
  KeyCodeName.rightAlt: 'alt',
  KeyCodeName.leftSuper: 'super',
  KeyCodeName.rightSuper: 'super',
  KeyCodeName.leftHyper: 'hyper',
  KeyCodeName.rightHyper: 'hyper',
  KeyCodeName.leftMeta: 'meta',
  KeyCodeName.rightMeta: 'meta',
};

/// Parses a generic modifier string (shift, ctrl, alt, etc.)
KeyModifiers? _parseGenericModifier(String mod) {
  return _genericModifiers[mod.toLowerCase()];
}

/// Parses a key string into a KeyCode
KeyCode _parseKey(String key) {
  if (key.toLowerCase() == 'space') {
    return const KeyCode.char(' ');
  }

  // Try to parse as a named key
  final namedKey = _parseNamedKey(key);
  if (namedKey != null) {
    return KeyCode.named(namedKey);
  }

  // If it's a single character, treat as char key
  if (key.length == 1) {
    return KeyCode.char(key);
  }

  throw ArgumentError('Unknown key: $key');
}

/// Converts a KeyCode to its spec string
String _keyToSpec(KeyCode code) {
  switch (code.kind) {
    case KeyCodeKind.char:
      if (code.char == ' ') return 'space';
      return code.char;
    case KeyCodeKind.named:
      final generic = _modifierKeyToGeneric[code.name];
      if (generic != null) return generic;
      return code.name.name;
  }
}

/// Parses a named key string
KeyCodeName? _parseNamedKey(String key) {
  final keyLower = key.toLowerCase();
  for (final value in KeyCodeName.values) {
    if (value == KeyCodeName.none) continue;
    if (value.name.toLowerCase() == keyLower) {
      return value;
    }
  }
  return null;
}
