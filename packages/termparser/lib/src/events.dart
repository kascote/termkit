import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import './extensions/int_extension.dart';
import 'events_types.dart';

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

/// Represent an empty event
final class NoneEvent extends InternalEvent with EquatableMixin {
  /// Constructs a new instance of [NoneEvent].
  const NoneEvent();
  @override
  List<Object> get props => [];
}

const _blankArray = <int>[];

/// Type of engine error
enum EngineErrorType {
  /// Malformed escape sequence
  malformedSequence,

  /// Unsupported escape sequence
  unsupportedSequence,

  /// Invalid parameter value
  invalidParameter,

  /// Unexpected escape character
  unexpectedEscape,
}

/// Error event dispatched when the engine cannot parse a sequence.
/// This is for structural errors (malformed sequences, invalid state transitions).
final class EngineErrorEvent extends ErrorEvent with EquatableMixin {
  /// The parameters of the sequence.
  final List<String> params;

  /// The character if there is one
  final String char;

  /// The block content if there is one
  final List<int> block;

  /// Error message describing what went wrong
  final String message;

  /// Type of error that occurred
  final EngineErrorType type;

  /// Raw bytes that caused the error (full sequence bytes accumulated)
  final List<int> rawBytes;

  /// Parser state when error occurred
  final String stateAtError;

  /// The specific byte that triggered the error
  final int? failingByte;

  /// Parameters collected before error occurred
  final List<String> partialParameters;

  /// Constructs a new instance of [EngineErrorEvent].
  const EngineErrorEvent(
    this.params, {
    this.char = '',
    this.block = _blankArray,
    this.message = '',
    this.type = EngineErrorType.malformedSequence,
    this.rawBytes = _blankArray,
    this.stateAtError = '',
    this.failingByte,
    this.partialParameters = const [],
  });

  @override
  List<Object?> get props => [
    params,
    char,
    block,
    message,
    type,
    rawBytes,
    stateAtError,
    failingByte,
    partialParameters,
  ];

  @override
  String toString() {
    final buffer = StringBuffer()..write('Engine error: $message');

    // Add sequence bytes as hex dump if available
    if (rawBytes.isNotEmpty) {
      buffer
        ..write('\n  Sequence: ')
        ..write(rawBytes.map((b) => b.toHexString()).join(' '))
        ..write(' (');
      for (final b in rawBytes) {
        if (b.isPrintable) {
          buffer.write(String.fromCharCode(b));
        } else if (b == 0x1B) {
          buffer.write('ESC');
        } else {
          buffer.write('.');
        }
        buffer.write(' ');
      }
      buffer.write(')');
    }

    if (partialParameters.isNotEmpty) {
      buffer.write('\n  Partial params: [${partialParameters.map((p) => '"$p"').join(', ')}]');
    }

    return buffer.toString();
  }
}

/// Represent a Key event.
@immutable
final class KeyEvent extends InputEvent with EquatableMixin {
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

  @override
  String toString() {
    return 'KeyEvent{code: $code, modifiers: $modifiers, eventType: $eventType, eventState: $eventState}';
  }
}

/// Represent a Cursor event.
final class CursorPositionEvent extends ResponseEvent with EquatableMixin {
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
final class MouseEvent extends InputEvent with EquatableMixin {
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
final class FocusEvent extends ResponseEvent with EquatableMixin {
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
final class KeyboardEnhancementFlagsEvent extends ResponseEvent with EquatableMixin {
  ///
  final int flags;

  ///
  final int mode;

  ///
  const KeyboardEnhancementFlagsEvent(this.flags, [this.mode = 1]);

  /// Returns an empty [KeyboardEnhancementFlagsEvent].
  factory KeyboardEnhancementFlagsEvent.empty() => const KeyboardEnhancementFlagsEvent(0);

  /// Add a flag to the current [KeyboardEnhancementFlagsEvent] and returns a new object.
  KeyboardEnhancementFlagsEvent add(int flag) => KeyboardEnhancementFlagsEvent(flags | flag);

  /// Check if a flag is present in the current [KeyboardEnhancementFlagsEvent].
  bool has(int flag) => flags.isSet(flag);

  @override
  List<Object> get props => [flags, mode];

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

  /// Send the Unicode codepoint as well as the keycode.
  static const int reportAssociatedText = 0x10;
}

/// Represent a Color event response from OSC 11
final class ColorQueryEvent extends ResponseEvent with EquatableMixin {
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
final class PrimaryDeviceAttributesEvent extends ResponseEvent with EquatableMixin {
  /// The type of attribute
  final DeviceAttributeType type;

  /// The value of the attribute
  final List<DeviceAttributeParams> params;

  /// Constructs a new instance of [PrimaryDeviceAttributesEvent].
  const PrimaryDeviceAttributesEvent(this.type, this.params);

  @override
  List<Object?> get props => [type, params];
}

/// Paste Action Event
final class PasteEvent extends InputEvent with EquatableMixin {
  /// The pasted text
  final String text;

  /// Constructs a new instance of [PasteEvent].
  const PasteEvent(this.text);

  @override
  List<Object> get props => [text];
}

/// Terminal Name and Version
final class NameAndVersionEvent extends ResponseEvent with EquatableMixin {
  /// The terminal name and n
  final String value;

  /// Constructs a new instance of [NameAndVersionEvent].
  const NameAndVersionEvent(this.value);

  @override
  List<Object> get props => [value];
}

/// Query Sync update status
///
/// ref: https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
final class QuerySyncUpdateEvent extends ResponseEvent with EquatableMixin {
  /// The sync update status code reported by the terminal
  final int code;

  /// The sync update status
  late final DECRPMStatus status;

  /// Constructs a new instance of [QuerySyncUpdateEvent].
  QuerySyncUpdateEvent(this.code) {
    status = DECRPMStatus.values.firstWhere((e) => e.value == code, orElse: () => DECRPMStatus.notRecognized);
  }

  @override
  List<Object> get props => [code];
}

/// Raw Key Event
final class RawKeyEvent extends InputEvent with EquatableMixin {
  /// The raw key values received
  final List<int> sequence;

  /// Constructs a new instance of [RawKeyEvent].
  RawKeyEvent(List<int> value) : sequence = List<int>.from(value);

  @override
  List<Object> get props => [sequence];
}

/// Query Terminal size in pixels
final class QueryTerminalWindowSizeEvent extends ResponseEvent with EquatableMixin {
  /// The terminal width
  final int width;

  /// The terminal height
  final int height;

  /// Constructs a new instance of [QueryTerminalWindowSizeEvent].
  const QueryTerminalWindowSizeEvent(this.width, this.height);

  @override
  List<Object> get props => [width, height];
}

/// Cliboard Copy Event
final class ClipboardCopyEvent extends ResponseEvent with EquatableMixin {
  /// The copied text
  final String text;

  /// Clipboard Source
  final ClipboardSource source;

  /// Constructs a new instance of [ClipboardCopyEvent].
  const ClipboardCopyEvent(this.source, this.text);

  @override
  List<Object> get props => [source, text];
}

/// Unicode Core Event
final class UnicodeCoreEvent extends ResponseEvent with EquatableMixin {
  /// The Unicode Core status reported by the terminal
  final int code;

  /// Get the Unicode Core status
  late final DECRPMStatus status;

  /// Constructs a new instance of [UnicodeCoreEvent].
  UnicodeCoreEvent(this.code) {
    status = DECRPMStatus.values.firstWhere((e) => e.value == code, orElse: () => DECRPMStatus.notRecognized);
  }

  @override
  List<Object> get props => [code];
}
