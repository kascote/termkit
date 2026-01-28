import 'package:meta/meta.dart';

import '../extensions/int_extension.dart';
import 'event_base.dart';
import 'shared.dart';

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

  /// Add extra events with KeyEventType set to keyRepeat or
  /// keyRelease when keys are auto repeated or released.
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
          listEquals(params, other.params);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(params));
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

/// DEC Report Mode status
///
/// ref: https://vt100.net/docs/vt510-rm/DECRPM.html
/// ref: https://vt100.net/docs/vt510-rm/DECRQM.html
enum DECRPMStatus {
  /// The requested query is not recognized
  notRecognized(0),

  /// The feature is enabled
  enabled(1),

  /// The feature is disabled
  disabled(2),

  /// The feature is permanently enabled
  permanentlyEnabled(3),

  /// The feature is permanently disabled
  permanentlyDisabled(4);

  const DECRPMStatus(this.value);

  /// The value of the status
  final int value;
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

/// Clipboard Sources
enum ClipboardSource {
  /// Clipboard source is unknown
  unknown,

  /// Clipboard source is clipboard
  clipboard,

  /// Clipboard source is primary
  primary,

  /// Clipboard source is secondary
  secondary,

  /// Clipboard source is selection
  selection,

  /// Clipboard source is cut buffer
  cutBuffer,
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

/// Color scheme mode reported by terminal.
enum ColorSchemeMode {
  /// Unknown color scheme
  unknown(0),

  /// Dark mode
  dark(1),

  /// Light mode
  light(2);

  const ColorSchemeMode(this.value);

  /// The numeric value for the color scheme.
  final int value;
}

/// Color scheme preference event (response to CSI 996 n).
@immutable
final class ColorSchemeEvent extends ResponseEvent {
  /// The color scheme mode code reported by the terminal.
  final int code;

  /// Get the color scheme mode.
  late final ColorSchemeMode mode;

  /// Constructs a new instance of [ColorSchemeEvent].
  ColorSchemeEvent(this.code) {
    mode = ColorSchemeMode.values.firstWhere((e) => e.value == code, orElse: () => ColorSchemeMode.unknown);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ColorSchemeEvent && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
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

/// Query in-band window resize status (DECRPM response for mode 2048).
///
/// ref: https://gist.github.com/rockorager/e695fb2924d36b2bcf1fff4a3704bd83
@immutable
final class QueryWindowResizeEvent extends ResponseEvent {
  /// The status code reported by the terminal.
  final int code;

  /// Get the DECRPM status.
  late final DECRPMStatus status;

  /// Constructs a new instance of [QueryWindowResizeEvent].
  QueryWindowResizeEvent(this.code) {
    status = DECRPMStatus.values.firstWhere((e) => e.value == code, orElse: () => DECRPMStatus.notRecognized);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryWindowResizeEvent && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Window resize event (in-band resize notification).
///
/// Sent when terminal is resized and in-band resize reporting is enabled.
///
/// ref: https://gist.github.com/rockorager/e695fb2924d36b2bcf1fff4a3704bd83
@immutable
final class WindowResizeEvent extends ResponseEvent {
  /// Terminal height in characters.
  final int heightChars;

  /// Terminal width in characters.
  final int widthChars;

  /// Terminal height in pixels (0 if unsupported).
  final int heightPixels;

  /// Terminal width in pixels (0 if unsupported).
  final int widthPixels;

  /// Constructs a new instance of [WindowResizeEvent].
  const WindowResizeEvent(
    this.heightChars,
    this.widthChars, [
    this.heightPixels = 0,
    this.widthPixels = 0,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowResizeEvent &&
          runtimeType == other.runtimeType &&
          heightChars == other.heightChars &&
          widthChars == other.widthChars &&
          heightPixels == other.heightPixels &&
          widthPixels == other.widthPixels;

  @override
  int get hashCode => Object.hash(heightChars, widthChars, heightPixels, widthPixels);
}
