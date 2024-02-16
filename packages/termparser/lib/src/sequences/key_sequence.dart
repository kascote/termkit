import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../extensions/int_extension.dart';

///
@immutable
class KeyCode extends Equatable {
  ///
  final KeyCodeName name;

  ///
  final String char;

  ///
  final MediaKeyCode media;

  ///
  final ModifierKeyCode modifiers;

  ///
  const KeyCode({
    this.name = KeyCodeName.none,
    this.char = '',
    this.media = MediaKeyCode.none,
    this.modifiers = ModifierKeyCode.none,
  });

  @override
  List<Object?> get props => [name, char, media, modifiers];
}

/// Represents key modifiers (shift, control, alt, etc.).
///
/// **Note:** `SUPER`, `HYPER`, and `META` can only be read if
/// [`KeyboardEnhancementFlags::DISAMBIGUATE_ESCAPE_CODES`] has been enabled with
/// [`PushKeyboardEnhancementFlags`].
@immutable
class KeyModifiers extends Equatable {
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
  List<Object> get props => [_value];

  ///
  bool has(int mask) => _value.isSet(mask);

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
}

const _keypad = 0x1;
const _capsLock = 0x8;
const _numLock = 0x8;
const _none = 0;

///
@immutable
class KeyEventState with EquatableMixin {
  final int _value;

  ///
  const KeyEventState(int value) : _value = value;

  ///
  int get value => _value;

  ///
  KeyEventState add(KeyEventState state) {
    return KeyEventState(_value | state.value);
  }

  @override
  List<Object> get props => [_value];

  ///
  bool get isKeypad => _value & _keypad == _keypad;

  ///
  bool get isCapsLock => _value & _capsLock == _capsLock;

  ///
  bool get isNumLock => _value & _numLock == _numLock;

  ///
  factory KeyEventState.keypad() => const KeyEventState(_keypad);

  ///
  factory KeyEventState.capsLock() => const KeyEventState(_capsLock);

  ///
  factory KeyEventState.numLock() => const KeyEventState(_numLock);

  ///
  factory KeyEventState.none() => const KeyEventState(_none);
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
enum ModifierKeyCode {
  /// Left Shift key.
  leftShift,

  /// Left Control key.
  leftControl,

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
  rightControl,

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

/// Device Attribute Codes
///
/// https://vt100.net/docs/vt510-rm/DA1.html
/// https://github.com/wez/wezterm/blob/main/termwiz/src/escape/csi.rs#L170
enum DeviceAttributeCodes {
  ///
  columns132(1),

  ///
  printer(2),

  ///
  regisGraphics(3),

  ///
  sixelGraphics(4),

  ///
  selectiveErase(6),

  ///
  userDefinedKeys(8),

  ///
  nationalReplacementCharsets(9),

  ///
  technicalCharacters(15),

  ///
  userWindows(18),

  ///
  horizontalScrolling(21),

  ///
  ansiColor(22),

  ///
  ansiTextLocator(29),

  ///
  unknown(999999);

  ///
  const DeviceAttributeCodes(this.value);

  ///
  final int value;
}
