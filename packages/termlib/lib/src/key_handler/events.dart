import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../shared/int_extension.dart';

///
sealed class Event {
  const Event();
}

/// None event
class NoneEvent extends Event {
  ///
  final List<int> sequence;

  ///
  NoneEvent(List<int> sequence) : sequence = List.from(sequence);

  @override
  String toString() => '${sequence.map((e) => e.hex2).join(':')} - ${sequence.map((e) => e.printable).join()}';
}

///
class TimeOutEvent extends Event {}

///
class ParserErrorEvent extends Event {
  ///
  final List<int> sequence;

  ///
  ParserErrorEvent(List<int> sequence) : sequence = List.from(sequence);

  @override
  String toString() => '${sequence.map((e) => e.hex2).join(':')} - ${sequence.map((e) => e.printable).join()}';
}

///
@immutable
class KeyEvent extends Event with EquatableMixin {
  ///
  final KeyCode code;

  ///
  final KeyModifiers modifiers;

  ///
  final KeyEventType eventType;

  ///
  final KeyEventState eventState;

  ///
  KeyEvent(
    this.code, {
    // this.key = KeyNames.none,
    this.modifiers = const KeyModifiers(0),
    this.eventType = KeyEventType.keyPress,
    this.eventState = const KeyEventState(0),
  });

  @override
  List<Object> get props => [code, modifiers, eventType, eventState];
}

const _keypad = 0x1;
const _capsLock = 0x8;
const _numLock = 0x8;
const _none = 0;

/// Represents key modifiers (shift, control, alt, etc.).
///
/// **Note:** `SUPER`, `HYPER`, and `META` can only be read if
/// [`KeyboardEnhancementFlags::DISAMBIGUATE_ESCAPE_CODES`] has been enabled with
/// [`PushKeyboardEnhancementFlags`].
@immutable
class KeyModifiers extends Equatable {
  final int _value;

  ///
  const KeyModifiers(int mask) : _value = mask;

  ///
  factory KeyModifiers.empty() => const KeyModifiers(0);

  ///
  int get value => _value;

  ///
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

///
enum KeyEventType {
  ///
  keyPress,

  ///
  keyRepeat,

  ///
  keyRelease,
}

///
@immutable
class KeyEventState extends Event with EquatableMixin {
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

///
class CursorPositionEvent extends Event with EquatableMixin {
  ///
  final int x;

  ///
  final int y;

  ///
  const CursorPositionEvent(this.x, this.y);

  @override
  List<Object> get props => [x, y];
}

///
class MouseEvent extends Event with EquatableMixin {
  ///
  final int x;

  ///
  final int y;

  ///
  final MouseEventKind kind;

  ///
  final KeyModifiers modifiers;

  ///
  const MouseEvent(this.x, this.y, this.kind, {this.modifiers = const KeyModifiers(0)});

  @override
  List<Object> get props => [x, y, kind, modifiers];
}

///
@immutable
class MouseEventKind extends Event with EquatableMixin {
  ///
  final MouseButton button;

  ///
  final MouseAction kind;

  ///
  const MouseEventKind(this.button, this.kind);

  ///
  factory MouseEventKind.down(MouseButton? button) => MouseEventKind(button ?? MouseButton.none, MouseAction.down);

  ///
  factory MouseEventKind.up(MouseButton? button) => MouseEventKind(button ?? MouseButton.none, MouseAction.up);

  ///
  factory MouseEventKind.drag(MouseButton? button) => MouseEventKind(button ?? MouseButton.none, MouseAction.drag);

  ///
  factory MouseEventKind.moved() => const MouseEventKind(MouseButton.none, MouseAction.moved);

  ///
  factory MouseEventKind.wheelUp() => const MouseEventKind(MouseButton.none, MouseAction.wheelUp);

  ///
  factory MouseEventKind.wheelDown() => const MouseEventKind(MouseButton.none, MouseAction.wheelDown);

  ///
  factory MouseEventKind.wheelLeft() => const MouseEventKind(MouseButton.none, MouseAction.wheelLeft);

  ///
  factory MouseEventKind.wheelRight() => const MouseEventKind(MouseButton.none, MouseAction.wheelRight);

  ///
  factory MouseEventKind.none() => const MouseEventKind(MouseButton.none, MouseAction.down);

  @override
  List<Object?> get props => [button, kind];
}

///
enum MouseAction {
  ///
  down,

  ///
  drag,

  ///
  up,

  ///
  moved,

  ///
  wheelUp,

  ///
  wheelDown,

  ///
  wheelLeft,

  ///
  wheelRight,
}

///
enum MouseButton {
  ///
  none,

  ///
  left,

  ///
  middle,

  ///
  right,
}

///
@immutable
class FocusEvent extends Event with EquatableMixin {
  ///
  final bool hasFocus;

  ///
  const FocusEvent({this.hasFocus = true});

  @override
  List<Object> get props => [hasFocus];
}

/// Represents special flags that tell compatible terminals to add extra information to keyboard events.
///
/// See <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement> for more information.
@immutable
class KeyboardEnhancementFlags extends Event with EquatableMixin {
  ///
  final int flags;

  ///
  final int mode;

  ///
  const KeyboardEnhancementFlags(this.flags, [this.mode = 1]);

  ///
  factory KeyboardEnhancementFlags.empty() => const KeyboardEnhancementFlags(0);

  ///
  KeyboardEnhancementFlags add(int flag) => KeyboardEnhancementFlags(flags | flag);

  ///
  bool has(int flag) => flags.isSet(flag);

  @override
  List<Object> get props => [flags];

  /// Represent Escape and modified keys using CSI-u sequences, so they can be unambiguously read.
  static const int disambiguateEscapeCodes = 0x1;

  /// Add extra events with [`KeyEvent.kind`] set to [`KeyEventKind::Repeat`] or
  /// [`KeyEventKind::Release`] when keys are auto repeated or released.
  static const int reportEventTypes = 0x2;

  /// Send [alternate keycodes](https://sw.kovidgoyal.net/kitty/keyboard-protocol/#key-codes)
  /// in addition to the base keycode. The alternate keycode overrides the base keycode in
  /// resulting `KeyEvent`s.
  static const int reportAlternateKeys = 0x4;

  /// Represent all keyboard events as CSI-u sequences. This is required to get repeat/release
  /// events for plain-text keys.
  static const int reportAllKeysAsEscapeCodes = 0x8;

  // Send the Unicode codepoint as well as the keycode.
  // *Note*: this is not yet supported.
  // static const int reportTextWithKeys = 0x10;
}

///
class PasteEvent extends Event with EquatableMixin {
  ///
  final String text;

  ///
  const PasteEvent(this.text);

  @override
  List<Object> get props => [text];
}

///
enum KeyCodeName {
  ///
  backSpace,

  ///
  enter,

  ///
  left,

  ///
  right,

  ///
  up,

  ///
  down,

  ///
  home,

  ///
  end,

  ///
  pageUp,

  ///
  pageDown,

  ///
  tab,

  ///
  backTab,

  ///
  delete,

  ///
  insert,

  ///
  nill,

  ///
  escape,

  ///
  capsLock,

  ///
  scrollLock,

  ///
  numLock,

  ///
  printScreen,

  ///
  pause,

  ///
  menu,

  ///
  keypadBegin,

  ///
  f1,

  ///
  f2,

  ///
  f3,

  ///
  f4,

  ///
  f5,

  ///
  f6,

  ///
  f7,

  ///
  f8,

  ///
  f9,

  ///
  f10,

  ///
  f11,

  ///
  f12,

  ///
  f13,

  ///
  f14,

  ///
  f15,

  ///
  f16,

  ///
  f17,

  ///
  f18,

  ///
  f19,

  ///
  f20,

  ///
  f21,

  ///
  f22,

  ///
  f23,

  ///
  f24,

  ///
  f25,

  ///
  f26,

  ///
  f27,

  ///
  f28,

  ///
  f29,

  ///
  f30,

  ///
  f31,

  ///
  f32,

  ///
  f33,

  ///
  f34,

  ///
  f35,
}

///
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

///
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
    this.name = KeyCodeName.nill,
    this.char = '',
    this.media = MediaKeyCode.none,
    this.modifiers = ModifierKeyCode.none,
  });

  @override
  List<Object?> get props => [name, char, media, modifiers];
}

///
class ColorQueryEvent extends Event with EquatableMixin {
  ///
  final int r;

  ///
  final int g;

  ///
  final int b;

  ///
  const ColorQueryEvent(this.r, this.g, this.b);

  @override
  List<Object> get props => [r, g, b];
}
