import 'package:meta/meta.dart';

import './extensions/int_extension.dart';
import 'events_types.dart';

/// Helper function for comparing lists
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

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
@immutable
final class NoneEvent extends InternalEvent {
  /// Constructs a new instance of [NoneEvent].
  const NoneEvent();

  @override
  bool operator ==(Object other) => identical(this, other) || other is NoneEvent && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
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
@immutable
final class EngineErrorEvent extends ErrorEvent {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineErrorEvent &&
          runtimeType == other.runtimeType &&
          _listEquals(params, other.params) &&
          char == other.char &&
          _listEquals(block, other.block) &&
          message == other.message &&
          type == other.type &&
          _listEquals(rawBytes, other.rawBytes) &&
          stateAtError == other.stateAtError &&
          failingByte == other.failingByte &&
          _listEquals(partialParameters, other.partialParameters);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(params),
    char,
    Object.hashAll(block),
    message,
    type,
    Object.hashAll(rawBytes),
    stateAtError,
    failingByte,
    Object.hashAll(partialParameters),
  );

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
final class KeyEvent extends InputEvent {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyEvent &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          modifiers == other.modifiers &&
          eventType == other.eventType &&
          eventState == other.eventState;

  @override
  int get hashCode => Object.hash(code, modifiers, eventType, eventState);

  @override
  String toString() {
    return 'KeyEvent{code: $code, modifiers: $modifiers, eventType: $eventType, eventState: $eventState}';
  }
}

/// Represent a Cursor event.
@immutable
final class CursorPositionEvent extends ResponseEvent {
  /// The x coordinate of the cursor event.
  final int x;

  /// The y coordinate of the cursor event.
  final int y;

  /// Constructs a new instance of [CursorPositionEvent].
  const CursorPositionEvent(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CursorPositionEvent && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Represent a Mouse event.
@immutable
final class MouseEvent extends InputEvent {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MouseEvent &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          button == other.button &&
          modifiers == other.modifiers;

  @override
  int get hashCode => Object.hash(x, y, button, modifiers);
}

/// Represent a Focus event.
@immutable
final class FocusEvent extends ResponseEvent {
  /// The focus state.
  final bool hasFocus;

  /// Constructs a new instance of [FocusEvent].
  const FocusEvent({this.hasFocus = true});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FocusEvent && runtimeType == other.runtimeType && hasFocus == other.hasFocus;

  @override
  int get hashCode => hasFocus.hashCode;
}

/// Returns information terminal keyboard support
///
/// See <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement> for more information.
@immutable
final class KeyboardEnhancementFlagsEvent extends ResponseEvent {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyboardEnhancementFlagsEvent &&
          runtimeType == other.runtimeType &&
          flags == other.flags &&
          mode == other.mode;

  @override
  int get hashCode => Object.hash(flags, mode);

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
@immutable
final class ColorQueryEvent extends ResponseEvent {
  /// The red color value.
  final int r;

  /// The green color value.
  final int g;

  /// The blue color value.
  final int b;

  /// Constructs a new instance of [ColorQueryEvent].
  const ColorQueryEvent(this.r, this.g, this.b);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorQueryEvent && runtimeType == other.runtimeType && r == other.r && g == other.g && b == other.b;

  @override
  int get hashCode => Object.hash(r, g, b);
}

/// Device Attribute
@immutable
final class PrimaryDeviceAttributesEvent extends ResponseEvent {
  /// The type of attribute
  final DeviceAttributeType type;

  /// The value of the attribute
  final List<DeviceAttributeParams> params;

  /// Constructs a new instance of [PrimaryDeviceAttributesEvent].
  const PrimaryDeviceAttributesEvent(this.type, this.params);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrimaryDeviceAttributesEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(params, other.params);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(params));
}

/// Paste Action Event
@immutable
final class PasteEvent extends InputEvent {
  /// The pasted text
  final String text;

  /// Constructs a new instance of [PasteEvent].
  const PasteEvent(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PasteEvent && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// Terminal Name and Version
@immutable
final class NameAndVersionEvent extends ResponseEvent {
  /// The terminal name and n
  final String value;

  /// Constructs a new instance of [NameAndVersionEvent].
  const NameAndVersionEvent(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NameAndVersionEvent && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Query Sync update status
///
/// ref: https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
@immutable
final class QuerySyncUpdateEvent extends ResponseEvent {
  /// The sync update status code reported by the terminal
  final int code;

  /// The sync update status
  late final DECRPMStatus status;

  /// Constructs a new instance of [QuerySyncUpdateEvent].
  QuerySyncUpdateEvent(this.code) {
    status = DECRPMStatus.values.firstWhere((e) => e.value == code, orElse: () => DECRPMStatus.notRecognized);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QuerySyncUpdateEvent && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Raw Key Event
@immutable
final class RawKeyEvent extends InputEvent {
  /// The raw key values received
  final List<int> sequence;

  /// Constructs a new instance of [RawKeyEvent].
  RawKeyEvent(List<int> value) : sequence = List<int>.from(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawKeyEvent && runtimeType == other.runtimeType && _listEquals(sequence, other.sequence);

  @override
  int get hashCode => Object.hashAll(sequence);
}

/// Query Terminal size in pixels
@immutable
final class QueryTerminalWindowSizeEvent extends ResponseEvent {
  /// The terminal width
  final int width;

  /// The terminal height
  final int height;

  /// Constructs a new instance of [QueryTerminalWindowSizeEvent].
  const QueryTerminalWindowSizeEvent(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryTerminalWindowSizeEvent &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Clipboard Copy Event
@immutable
final class ClipboardCopyEvent extends ResponseEvent {
  /// The copied text
  final String text;

  /// Clipboard Source
  final ClipboardSource source;

  /// Constructs a new instance of [ClipboardCopyEvent].
  const ClipboardCopyEvent(this.source, this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardCopyEvent && runtimeType == other.runtimeType && source == other.source && text == other.text;

  @override
  int get hashCode => Object.hash(source, text);
}

/// Unicode Core Event
@immutable
final class UnicodeCoreEvent extends ResponseEvent {
  /// The Unicode Core status reported by the terminal
  final int code;

  /// Get the Unicode Core status
  late final DECRPMStatus status;

  /// Constructs a new instance of [UnicodeCoreEvent].
  UnicodeCoreEvent(this.code) {
    status = DECRPMStatus.values.firstWhere((e) => e.value == code, orElse: () => DECRPMStatus.notRecognized);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UnicodeCoreEvent && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}
