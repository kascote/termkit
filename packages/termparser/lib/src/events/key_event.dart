import 'package:meta/meta.dart';

import '../extensions/int_extension.dart';
import 'event_base.dart';

/// Discriminator for KeyCode variants
enum KeyCodeKind {
  /// Named key (F1-F35, Enter, Escape, arrows, etc.)
  named,

  /// Printable character
  char,

  /// Media key (play, pause, volumeUp, etc.)
  media,

  /// Modifier key itself (leftCtrl, rightShift, etc.)
  modifier,
}

/// Represents a key pressed on the keyboard.
/// This class is used for the legacy key events as well the enhanced key events.
/// used on the Kitty protocol.
///
/// **Note:** need to have KeyboardEnhancementFlags.disambiguateEscapeCodes enabled
/// to [media] and/or [modifierKey] to be populated.
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

  /// Contains the media key code if is a media key (play, pause, etc).
  /// Only populated when kind == KeyCodeKind.media
  final MediaKeyCode media;

  /// Contains the modifier key itself (leftCtrl, rightShift, etc).
  /// Only populated when kind == KeyCodeKind.modifier
  final ModifierKey modifierKey;

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
    this.media = MediaKeyCode.none,
    this.modifierKey = ModifierKey.none,
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

  /// Constructs a media key
  const KeyCode.media(MediaKeyCode media)
    : this._(
        kind: KeyCodeKind.media,
        media: media,
      );

  /// Constructs a modifier key itself
  const KeyCode.modifier(ModifierKey modifierKey)
    : this._(
        kind: KeyCodeKind.modifier,
        modifierKey: modifierKey,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyCode &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          name == other.name &&
          char == other.char &&
          media == other.media &&
          modifierKey == other.modifierKey &&
          baseLayoutKey == other.baseLayoutKey;

  @override
  int get hashCode => Object.hash(kind, name, char, media, modifierKey, baseLayoutKey);

  /// Create a new instance of [KeyCode] with the given parameters.
  KeyCode copyWith({
    KeyCodeKind? kind,
    KeyCodeName? name,
    String? char,
    MediaKeyCode? media,
    ModifierKey? modifierKey,
    int? baseLayoutKey,
  }) {
    return KeyCode._(
      kind: kind ?? this.kind,
      name: name ?? this.name,
      char: char ?? this.char,
      media: media ?? this.media,
      modifierKey: modifierKey ?? this.modifierKey,
      baseLayoutKey: baseLayoutKey ?? this.baseLayoutKey,
    );
  }

  @override
  String toString() {
    return 'KeyCode{kind: $kind, name: $name, char: $char, media: $media, modifierKey: $modifierKey, baseLayoutKey: $baseLayoutKey}';
  }
}

/// Represents key modifiers (shift, control, alt, etc.).
///
/// **Note:** `superKey`, `hyper`, and `meta` can only be read if
/// KeyboardEnhancementFlags.disambiguateEscapeCodes is enabled
@immutable
class KeyModifiers {
  final int _value;

  /// Constructs a new instance of [KeyModifiers].
  const KeyModifiers(int mask) : _value = mask;

  /// Constructs a new instance of [KeyModifiers] with no modifiers.
  factory KeyModifiers.empty() => const KeyModifiers(0);

  /// Returns the value of the modifiers.
  int get value => _value;

  /// Add a modifier to the current set of modifiers.
  KeyModifiers add(int modifier) => KeyModifiers(_value | modifier);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is KeyModifiers && runtimeType == other.runtimeType && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  ///
  bool has(int mask) => _value.isSet(mask);

  ///
  bool get isCtrl => _value == KeyModifiers.ctrl;

  ///
  bool get isShift => _value == KeyModifiers.shift;

  ///
  bool get isAlt => _value == KeyModifiers.alt;

  ///
  bool get isSuperKey => _value == KeyModifiers.superKey;

  ///
  bool get isHyper => _value == KeyModifiers.hyper;

  ///
  bool get isMeta => _value == KeyModifiers.meta;

  ///
  static const shift = 0x1;

  ///
  static const alt = 0x2;

  ///
  static const ctrl = 0x4;

  ///
  static const superKey = 0x8;

  ///
  static const hyper = 0x10;

  ///
  static const meta = 0x20;

  ///
  static const none = 0x0;

  @override
  String toString() {
    return 'KeyModifiers{shift: ${has(shift)}, alt: ${has(alt)}, ctrl: ${has(ctrl)}, superKey: ${has(superKey)}, hyper: ${has(hyper)}, meta: ${has(meta)}}';
  }
}

const _keypad = 0x1;
const _capsLock = 0x2;
const _numLock = 0x4;
const _none = 0;

/// Represents the state of the keyboard.
@immutable
class KeyEventState {
  final int _value;

  /// Constructs a new instance of [KeyEventState].
  const KeyEventState(int value) : _value = value;

  /// Returns the value of the state.
  int get value => _value;

  /// Add a state to the current set of states.
  KeyEventState add(KeyEventState state) {
    return KeyEventState(_value | state.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is KeyEventState && runtimeType == other.runtimeType && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  /// Returns `true` if is a key from the keypad
  bool get isKeypad => _value & _keypad == _keypad;

  /// Returns `true` if the caps is in the key event
  bool get isCapsLock => _value & _capsLock == _capsLock;

  /// Returns `true` if the num lock is in the key event.
  bool get isNumLock => _value & _numLock == _numLock;

  /// Creates a new instance of [KeyEventState] with keypad enabled.
  factory KeyEventState.keypad() => const KeyEventState(_keypad);

  /// Creates a new instance of [KeyEventState] with caps lock enabled.
  factory KeyEventState.capsLock() => const KeyEventState(_capsLock);

  /// Creates a new instance of [KeyEventState] with num lock enabled.
  factory KeyEventState.numLock() => const KeyEventState(_numLock);

  /// Creates a new instance of [KeyEventState] with none of the states enabled.
  factory KeyEventState.none() => const KeyEventState(_none);

  @override
  String toString() {
    if (_value == _none) return 'KeyEventState: {none}';
    return 'KeyEventState: {isKeypad: $isKeypad, isCapsLock: $isCapsLock, isNumLock: $isNumLock}';
  }
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
}

/// Enum for Media Keys
enum MediaKeyCode {
  /// Play media key.
  play,

  /// Pause media key.
  pause,

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

  ///
  none,
}

/// Enum for Modifier Keys
enum ModifierKey {
  /// Left Shift key.
  leftShift,

  /// Left Control key.
  leftCtrl,

  /// Left Alt key.
  leftAlt,

  /// Left Super key.
  leftSuper,

  /// Left Hyper key.
  leftHyper,

  /// Left Meta key.
  leftMeta,

  /// Right Shift key.
  rightShift,

  /// Right Control key.
  rightCtrl,

  /// Right Alt key.
  rightAlt,

  /// Right Super key.
  rightSuper,

  /// Right Hyper key.
  rightHyper,

  /// Right Meta key.
  rightMeta,

  /// Iso Level3 Shift key.
  isoLevel3Shift,

  /// Iso Level5 Shift key.
  isoLevel5Shift,

  ///
  none,
}

/// Enum for Key Events Types
enum KeyEventType {
  /// Key press event.
  keyPress,

  /// Key release event.
  keyRepeat,

  /// Key release event.
  keyRelease,
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

  /// The Key state
  final KeyEventState eventState;

  /// Specific modifier keys that were pressed (leftCtrl vs rightCtrl).
  /// Empty set means wildcard (matches any specific modifiers).
  /// Populated when Kitty protocol provides specific modifier info.
  final Set<ModifierKey> modifierKeys;

  /// Constructs a new instance of [KeyEvent].
  const KeyEvent(
    this.code, {
    this.modifiers = const KeyModifiers(0),
    this.eventType = KeyEventType.keyPress,
    this.eventState = const KeyEventState(0),
    this.modifierKeys = const {},
  });

  /// Parses a key specification string into a [KeyEvent].
  ///
  /// Supports both generic and specific modifier syntax:
  /// - 'a' → single character key
  /// - 'enter' → named key (use exact enum names)
  /// - 'ctrl+a' → generic modifier + key
  /// - 'leftCtrl+a' → specific modifier + key (also sets generic ctrl)
  /// - 'shift+ctrl+enter' → multiple modifiers
  /// - 'leftShift+rightCtrl+f1' → specific modifiers
  /// - 'play' → media key (use exact enum names)
  /// - 'ctrl+raiseVolume' → media key with modifier
  /// - 'leftCtrl' → modifier key itself
  ///
  /// Key names are case-insensitive and match the enum names from
  /// [KeyCodeName], [MediaKeyCode], and [ModifierKey].
  ///
  /// Throws [ArgumentError] if the specification is invalid.
  factory KeyEvent.fromString(String spec) {
    if (spec.isEmpty) {
      throw ArgumentError('Key specification cannot be empty');
    }

    final parts = spec.split('+');
    final keyPart = parts.last;
    final modifierParts = parts.length > 1 ? parts.sublist(0, parts.length - 1) : <String>[];

    var modifierMask = 0;
    final specificMods = <ModifierKey>{};

    for (final mod in modifierParts) {
      final specificMod = _parseSpecificModifier(mod);
      if (specificMod != null) {
        specificMods.add(specificMod);
        modifierMask |= _getGenericModifierForSpecific(specificMod);
        continue;
      }

      final genericMod = _parseGenericModifier(mod);
      if (genericMod != null) {
        modifierMask |= genericMod;
        continue;
      }

      throw ArgumentError('Unknown modifier: $mod');
    }

    final keyCode = _parseKey(keyPart);

    return KeyEvent(
      keyCode,
      modifiers: KeyModifiers(modifierMask),
      modifierKeys: specificMods,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyEvent &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          modifiers == other.modifiers &&
          eventType == other.eventType &&
          eventState == other.eventState;
  // NOTE: modifierKeys is intentionally NOT compared for wildcard matching

  @override
  int get hashCode => Object.hash(code, modifiers, eventType, eventState);
  // NOTE: modifierKeys is intentionally NOT included for wildcard matching

  /// Creates a copy of this [KeyEvent] with the given fields replaced.
  KeyEvent copyWith({
    KeyCode? code,
    KeyModifiers? modifiers,
    Set<ModifierKey>? modifierKeys,
    KeyEventType? eventType,
    KeyEventState? eventState,
  }) {
    return KeyEvent(
      code ?? this.code,
      modifiers: modifiers ?? this.modifiers,
      eventType: eventType ?? this.eventType,
      eventState: eventState ?? this.eventState,
      modifierKeys: modifierKeys ?? this.modifierKeys,
    );
  }

  @override
  String toString() {
    return 'KeyEvent{code: $code, modifiers: $modifiers, eventType: $eventType, eventState: $eventState, modifierKeys: $modifierKeys}';
  }
}

/// Returns the generic modifier mask for a specific modifier key
int _getGenericModifierForSpecific(ModifierKey specificMod) {
  switch (specificMod) {
    case ModifierKey.leftShift:
    case ModifierKey.rightShift:
      return KeyModifiers.shift;
    case ModifierKey.leftCtrl:
    case ModifierKey.rightCtrl:
      return KeyModifiers.ctrl;
    case ModifierKey.leftAlt:
    case ModifierKey.rightAlt:
      return KeyModifiers.alt;
    case ModifierKey.leftSuper:
    case ModifierKey.rightSuper:
      return KeyModifiers.superKey;
    case ModifierKey.leftHyper:
    case ModifierKey.rightHyper:
      return KeyModifiers.hyper;
    case ModifierKey.leftMeta:
    case ModifierKey.rightMeta:
      return KeyModifiers.meta;
    case ModifierKey.isoLevel3Shift:
    case ModifierKey.isoLevel5Shift:
    case ModifierKey.none:
      return 0;
  }
}

/// Map of generic modifier names to their bit masks
const Map<String, int> _genericModifiers = {
  'shift': KeyModifiers.shift,
  'ctrl': KeyModifiers.ctrl,
  'alt': KeyModifiers.alt,
  'super': KeyModifiers.superKey,
  'hyper': KeyModifiers.hyper,
  'meta': KeyModifiers.meta,
};

/// Parses a generic modifier string (shift, ctrl, alt, etc.)
int? _parseGenericModifier(String mod) {
  return _genericModifiers[mod.toLowerCase()];
}

/// Parses a key string into a KeyCode
KeyCode _parseKey(String key) {
  // Try to parse as a modifier key itself
  final modifierKey = _parseSpecificModifier(key);
  if (modifierKey != null) {
    return KeyCode.modifier(modifierKey);
  }

  // Try to parse as a media key
  final mediaKey = _parseMediaKey(key);
  if (mediaKey != null) {
    return KeyCode.media(mediaKey);
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

/// Parses a specific modifier string (leftCtrl, rightShift, etc.)
ModifierKey? _parseSpecificModifier(String mod) {
  final modLower = mod.toLowerCase();
  for (final value in ModifierKey.values) {
    if (value == ModifierKey.none) continue;
    if (value == ModifierKey.isoLevel3Shift) continue;
    if (value == ModifierKey.isoLevel5Shift) continue;
    if (value.name.toLowerCase() == modLower) {
      return value;
    }
  }
  return null;
}

/// Parses a media key string
MediaKeyCode? _parseMediaKey(String key) {
  final keyLower = key.toLowerCase();
  for (final value in MediaKeyCode.values) {
    if (value == MediaKeyCode.none) continue;
    if (value.name.toLowerCase() == keyLower) {
      return value;
    }
  }
  return null;
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
