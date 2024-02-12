import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import './extensions/int_extension.dart';
import './sequences/key_sequence.dart';
import 'sequences/mouse_data.dart';

/// Base class for all sequences.
final class Sequence {
  /// Constructor
  const Sequence();
}

/// Represent an empty sequence
final class NoneSequence extends Sequence with EquatableMixin {
  /// Constructs a new instance of [NoneSequence].
  const NoneSequence();
  @override
  List<Object> get props => [];
}

/// Represent a Key event sequence.
@immutable
final class KeySequence extends Sequence with EquatableMixin {
  /// The key code.
  final KeyCode code;

  /// The key modifiers that could have been pressed.
  final KeyModifiers modifiers;

  /// The type of the event.
  final KeyEventType eventType;

  /// The Key state
  final KeyEventState eventState;

  /// Constructs a new instance of [KeySequence].
  const KeySequence(
    this.code, {
    this.modifiers = const KeyModifiers(0),
    this.eventType = KeyEventType.keyPress,
    this.eventState = const KeyEventState(0),
  });

  @override
  List<Object> get props => [code, modifiers, eventType, eventState];
}

/// Represent a Cursor event sequence.
final class CursorSequence extends Sequence with EquatableMixin {
  /// The x coordinate of the cursor event.
  final int x;

  /// The y coordinate of the cursor event.
  final int y;

  /// Constructs a new instance of [CursorSequence].
  const CursorSequence(this.x, this.y);

  @override
  List<Object> get props => [x, y];
}

/// Represent a Mouse event sequence.
final class MouseSequence extends Sequence with EquatableMixin {
  /// The x coordinate of the mouse event.
  final int x;

  /// The y coordinate of the mouse event.
  final int y;

  /// The button that was pressed.
  final MouseButtonEvent button;

  /// The key modifiers that could have been pressed.
  final KeyModifiers modifiers;

  /// Constructs a new instance of [MouseSequence].
  const MouseSequence(this.x, this.y, this.button, {this.modifiers = const KeyModifiers(0)});

  @override
  List<Object> get props => [x, y, button, modifiers];
}

/// Represent a Focus event sequence.
final class FocusSequence extends Sequence with EquatableMixin {
  /// The focus state.
  final bool hasFocus;

  /// Constructs a new instance of [FocusSequence].
  const FocusSequence({this.hasFocus = true});

  @override
  List<Object> get props => [hasFocus];
}

/// Returns information terminal keyboard support
///
/// See <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement> for more information.
@immutable
final class KeyboardEnhancementFlags extends Sequence with EquatableMixin {
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

/// Represent a Color sequence response from OSC 11
final class ColorQuerySequence extends Sequence with EquatableMixin {
  /// The red color value.
  final int r;

  /// The green color value.
  final int g;

  /// The blue color value.
  final int b;

  /// Constructs a new instance of [ColorQuerySequence].
  const ColorQuerySequence(this.r, this.g, this.b);

  @override
  List<Object> get props => [r, g, b];
}
