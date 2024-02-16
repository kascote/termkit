import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'extensions/int_extension.dart';

/// Represents a key pressed on the keyboard.
/// This class is used for the legacy key events as well the enhanced key events.
/// used on the Kitty protocol.
///
/// **Note:** need to have [KeyboardEnhancementFlags.disambiguateEscapeCodes] enabled
/// to [media] and/or [modifiers] to be populated.
///
/// ref: https://sw.kovidgoyal.net/kitty/keyboard-protocol/
@immutable
class KeyCode extends Equatable {
  /// Contains the name of the key if is a named key (enter, esc, pgUp, etc).
  final KeyCodeName name;

  /// Contains the character of the key if is a printable character.
  final String char;

  /// Contains the media key code if is a media key (play, pause, etc).
  final MediaKeyCode media;

  /// Contains the modifiers applied to the key (shift, ctrl, alt, etc).
  final ModifierKeyCode modifiers;

  /// Constructs a new instance of [KeyCode].
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
/// **Note:** `superKey`, `hyper`, and `meta` can only be read if
/// [KeyboardEnhancementFlags.disambiguateEscapeCodes] is enabled
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

/// Represents the state of the keyboard.
@immutable
class KeyEventState with EquatableMixin {
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
  List<Object> get props => [_value];

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

/// Device Attribute Type
enum DeviceAttributeType {
  /// Unknown
  unknown(0),

  /// vt100
  vt100WithAdvancedVideoOption(12), // 1,2

  /// vt101
  vt101WithNoOptions(10), // 1,0

  /// vt102
  vt102(6),

  /// vt220
  vt220(62),

  /// vt320
  vt320(63),

  /// vt420
  vt420(64),

  /// vt500
  vt500(65);

  /// The value of the attribute
  const DeviceAttributeType(this.value);

  /// The value of the attribute
  final int value;
}

/// Device Attribute Params
///
/// https://vt100.net/docs/vt510-rm/DA1.html
/// https://github.com/wez/wezterm/blob/main/termwiz/src/escape/csi.rs#L170
enum DeviceAttributeParams {
  /// 132 columns support
  columns132(1),

  /// Printer port
  printer(2),

  /// ReGIS Graphics
  regisGraphics(3),

  /// Sixel Graphics
  sixelGraphics(4),

  /// Selective Erase
  selectiveErase(6),

  /// User-defined keys
  userDefinedKeys(8),

  /// National replacement character sets (NRCS)
  nationalReplacementCharsets(9),

  /// Technical character set
  technicalCharacters(15),

  /// Windowing capability
  userWindows(18),

  /// Horizontal scrolling
  horizontalScrolling(21),

  /// ANSI color
  ansiColor(22),

  /// ANSI text locator
  ansiTextLocator(29),

  /// Unknown
  unknown(999999);

  /// The value of the attribute
  const DeviceAttributeParams(this.value);

  ///
  final int value;
}

/// Represents a Mouse Event
@immutable
final class MouseButtonEvent extends Equatable {
  /// Mouse Button that was pressed or released
  final MouseButton button;

  /// The kind of action that was performed
  final MouseButtonAction action;

  /// Constructs a new instance of [MouseButtonEvent].
  const MouseButtonEvent(this.button, this.action);

  /// Constructs a new instance of [MouseButtonEvent] with the given button and [MouseButtonAction.down]
  factory MouseButtonEvent.down(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.down);

  /// Constructs a new instance of [MouseButtonEvent] with the given button and [MouseButtonAction.up]
  factory MouseButtonEvent.up(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.up);

  /// Constructs a new instance of [MouseButtonEvent] with the given button and [MouseButtonAction.drag]
  factory MouseButtonEvent.drag(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.drag);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.moved]
  factory MouseButtonEvent.moved(MouseButton? button) =>
      MouseButtonEvent(button ?? MouseButton.none, MouseButtonAction.moved);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelUp]
  factory MouseButtonEvent.wheelUp() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelUp);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelDown]
  factory MouseButtonEvent.wheelDown() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelDown);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelLeft]
  factory MouseButtonEvent.wheelLeft() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelLeft);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.wheelRight]
  factory MouseButtonEvent.wheelRight() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.wheelRight);

  /// Constructs a new instance of [MouseButtonEvent] with [MouseButtonAction.none]
  factory MouseButtonEvent.none() => const MouseButtonEvent(MouseButton.none, MouseButtonAction.none);

  @override
  List<Object?> get props => [button, action];
}

/// Represent a Mouse action
enum MouseButtonAction {
  /// Mouse button was pressed
  down,

  /// Mouse is in drag mode
  drag,

  /// Mouse button was released
  up,

  /// Mouse was moved
  moved,

  /// Mouse wheel was moved up
  wheelUp,

  /// Mouse wheel was moved down
  wheelDown,

  /// Mouse wheel was moved left
  wheelLeft,

  /// Mouse wheel was moved right
  wheelRight,

  /// No mouse action
  none,
}

/// Represent a Mouse button
enum MouseButton {
  /// No button
  none,

  /// Left mouse button
  left,

  /// Middle mouse button
  middle,

  /// Right mouse button
  right,
}
