import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import './extensions/int_extension.dart';
import 'events_types.dart';

/// Base class for all events.
final class Event {
  /// Constructor
  const Event();
}

/// Represent an empty event
final class NoneEvent extends Event with EquatableMixin {
  /// Constructs a new instance of [NoneEvent].
  const NoneEvent();
  @override
  List<Object> get props => [];
}

const _blankArray = <int>[];

/// Error event dispatched when can not parse a sequence.
final class ParserErrorEvent extends Event with EquatableMixin {
  /// The parameters of the sequence.
  final List<String> params;

  /// The character if there is one
  final String char;

  /// The block content if there is one
  final List<int> block;

  /// Constructs a new instance of [ParserErrorEvent].
  const ParserErrorEvent(this.params, {this.char = '', this.block = _blankArray});

  @override
  List<Object> get props => [params, char, block];
}

/// Represent a Key event.
@immutable
final class KeyEvent extends Event with EquatableMixin {
  /// The key code.
  final KeyCode code;

  /// The key modifiers that could have been pressed.
  final KeyModifiers modifiers;

  /// The type of the event.
  final KeyEventType eventType;

  /// The Key state
  final KeyEventState eventState;

  /// Constructs a new instance of [KeyEvent].
  const KeyEvent(
    this.code, {
    this.modifiers = const KeyModifiers(0),
    this.eventType = KeyEventType.keyPress,
    this.eventState = const KeyEventState(0),
  });

  @override
  List<Object> get props => [code, modifiers, eventType, eventState];
}

/// Represent a Cursor event.
final class CursorPositionEvent extends Event with EquatableMixin {
  /// The x coordinate of the cursor event.
  final int x;

  /// The y coordinate of the cursor event.
  final int y;

  /// Constructs a new instance of [CursorPositionEvent].
  const CursorPositionEvent(this.x, this.y);

  @override
  List<Object> get props => [x, y];
}

/// Represent a Mouse event.
final class MouseEvent extends Event with EquatableMixin {
  /// The x coordinate of the mouse event.
  final int x;

  /// The y coordinate of the mouse event.
  final int y;

  /// The button that was pressed.
  final MouseButton button;

  /// The key modifiers that could have been pressed.
  final KeyModifiers modifiers;

  /// Constructs a new instance of [MouseEvent].
  const MouseEvent(this.x, this.y, this.button, {this.modifiers = const KeyModifiers(0)});

  @override
  List<Object> get props => [x, y, button, modifiers];
}

/// Represent a Focus event.
final class FocusEvent extends Event with EquatableMixin {
  /// The focus state.
  final bool hasFocus;

  /// Constructs a new instance of [FocusEvent].
  const FocusEvent({this.hasFocus = true});

  @override
  List<Object> get props => [hasFocus];
}

/// Returns information terminal keyboard support
///
/// See <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement> for more information.
@immutable
final class KeyboardEnhancementFlags extends Event with EquatableMixin {
  ///
  final int flags;

  ///
  final int mode;

  ///
  const KeyboardEnhancementFlags(this.flags, [this.mode = 1]);

  /// Returns an empty [KeyboardEnhancementFlags].
  factory KeyboardEnhancementFlags.empty() => const KeyboardEnhancementFlags(0);

  /// Add a flag to the current [KeyboardEnhancementFlags] and returns a new object.
  KeyboardEnhancementFlags add(int flag) => KeyboardEnhancementFlags(flags | flag);

  /// Check if a flag is present in the current [KeyboardEnhancementFlags].
  bool has(int flag) => flags.isSet(flag);

  @override
  List<Object> get props => [flags];

  /// Represent Escape and modified keys using CSI-u sequences, so they can be unambiguously read.
  static const int disambiguateEscapeCodes = 0x1;

  /// Add extra events with [KeyEventType] set to [KeyEventType.keyRepeat] or
  /// [KeyEventType.keyRelease] when keys are auto repeated or released.
  static const int reportEventTypes = 0x2;

  /// Send [alternate keycodes](https://sw.kovidgoyal.net/kitty/keyboard-protocol/#key-codes)
  /// in addition to the base keycode. The alternate keycode overrides the base keycode in
  /// resulting `KeyEvent`s.
  static const int reportAlternateKeys = 0x4;

  /// Represent all keyboard events as CSI-u sequences. This is required to get repeat/release
  /// events for plain-text keys.
  static const int reportAllKeysAsEscapeCodes = 0x8;

  // Send the Unicode codepoint as well as the keycode.
  // static const int reportTextWithKeys = 0x10;
}

/// Represent a Color event response from OSC 11
final class ColorQueryEvent extends Event with EquatableMixin {
  /// The red color value.
  final int r;

  /// The green color value.
  final int g;

  /// The blue color value.
  final int b;

  /// Constructs a new instance of [ColorQueryEvent].
  const ColorQueryEvent(this.r, this.g, this.b);

  @override
  List<Object> get props => [r, g, b];
}

/// Device Attribute
final class PrimaryDeviceAttributesEvent extends Event with EquatableMixin {
  /// The type of attribute
  final DeviceAttributeType type;

  /// The value of the attribute
  final List<DeviceAttributeParams> params;

  /// Constructs a new instance of [PrimaryDeviceAttributesEvent].
  const PrimaryDeviceAttributesEvent(this.type, this.params);

  /// Constructs a new instance of [PrimaryDeviceAttributesEvent] with the given params.
  factory PrimaryDeviceAttributesEvent.fromParams(List<String> params) {
    return switch (params) {
      ['1', '0'] => const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt101WithNoOptions, []),
      ['6'] => const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt102, []),
      ['1', '2'] => const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt100WithAdvancedVideoOption, []),
      ['62', ...] => PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, _genParams(params.sublist(1))),
      ['63', ...] => PrimaryDeviceAttributesEvent(DeviceAttributeType.vt320, _genParams(params.sublist(1))),
      ['64', ...] => PrimaryDeviceAttributesEvent(DeviceAttributeType.vt420, _genParams(params.sublist(1))),
      ['65', ...] => PrimaryDeviceAttributesEvent(DeviceAttributeType.vt500, _genParams(params.sublist(1))),
      _ => const PrimaryDeviceAttributesEvent(DeviceAttributeType.unknown, [])
    };
  }

  @override
  List<Object?> get props => [type, params];

  static List<DeviceAttributeParams> _genParams(List<String> params) {
    return params.fold(<DeviceAttributeParams>[], (acc, p) {
      if (p.isEmpty) return acc;
      final code = DeviceAttributeParams.values
          .firstWhere((e) => e.value == int.parse(p), orElse: () => DeviceAttributeParams.unknown);
      if (code != DeviceAttributeParams.unknown) return acc..add(code);
      return acc;
    });
  }
}

/// Paste Action Event
final class PasteEvent extends Event with EquatableMixin {
  /// The pasted text
  final String text;

  /// Constructs a new instance of [PasteEvent].
  const PasteEvent(this.text);

  @override
  List<Object> get props => [text];
}

/// Terminal Name and Version
final class NameAndVersionEvent extends Event with EquatableMixin {
  /// The terminal name and version
  final String value;

  /// Constructs a new instance of [NameAndVersionEvent].
  const NameAndVersionEvent(this.value);

  @override
  List<Object> get props => [value];
}
