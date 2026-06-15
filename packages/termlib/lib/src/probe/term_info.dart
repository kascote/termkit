import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';

import '../colors.dart';
import 'query_result.dart';

// Re-export termparser types used in TermInfo
export 'package:termparser/termparser_events.dart'
    show ColorSchemeMode, DECRPMStatus, DeviceAttributeParams, DeviceAttributeType;

/// Query types for terminal capability probing.
enum ProbeQuery {
  /// Primary device attributes (DA1)
  deviceAttrs,

  /// Terminal name and version
  terminalVersion,

  /// Foreground color (OSC 10)
  foregroundColor,

  /// Background color (OSC 11)
  backgroundColor,

  /// Synchronous update support
  syncUpdate,

  /// Keyboard enhancement capabilities
  keyboardCapabilities,

  /// Window size in pixels
  windowSizePixels,

  /// Unicode Core support
  unicodeCore,

  /// Color scheme (light/dark mode)
  colorScheme,

  /// In-band window resize reporting
  inBandResize,

  /// Bracketed paste reporting
  bracketedPaste,
}

/// The [ProbeQuery] subset whose results seed live mode state (`TermModes`):
/// bracketed paste, in-band resize, unicode core, and keyboard capabilities.
/// These map one-to-one to the seedable `TerminalMode`s (see
/// `InteractiveTerm._seedModesFromProbe`). Used as `TermRunner`'s default probe
/// set so its build-time snapshot reflects inherited terminal state without
/// paying for the queries that don't feed a mode.
const Set<ProbeQuery> seedableProbeQueries = {
  ProbeQuery.bracketedPaste,
  ProbeQuery.inBandResize,
  ProbeQuery.unicodeCore,
  ProbeQuery.keyboardCapabilities,
};

/// Device attributes from DA1 query.
@immutable
class DeviceAttributes {
  /// The device type.
  final DeviceAttributeType type;

  /// The device attribute parameters.
  final List<DeviceAttributeParams> params;

  /// Creates device attributes.
  const DeviceAttributes(this.type, this.params);

  /// Creates from [PrimaryDeviceAttributesEvent].
  factory DeviceAttributes.fromEvent(PrimaryDeviceAttributesEvent event) => DeviceAttributes(event.type, event.params);

  @override
  String toString() => 'DeviceAttributes($type, $params)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DeviceAttributes && other.type == type && _listEquals(other.params, params));

  @override
  int get hashCode => Object.hash(type, Object.hashAll(params));
}

/// Sync update status.
enum SyncUpdateStatus {
  /// Sync updates are enabled.
  enabled,

  /// Sync updates are disabled.
  disabled,

  /// Status is unknown.
  unknown,
}

/// Keyboard enhancement flags.
@immutable
class KeyboardFlags {
  /// Disambiguate escape codes.
  final bool disambiguateEscapeCodes;

  /// Report event types (keyRepeat, keyRelease).
  final bool reportEventTypes;

  /// Report alternate keys.
  final bool reportAlternateKeys;

  /// Report all keys as escape codes.
  final bool reportAllKeysAsEscapeCodes;

  /// Report associated text.
  final bool reportAssociatedText;

  /// Creates keyboard flags.
  const KeyboardFlags({
    this.disambiguateEscapeCodes = false,
    this.reportEventTypes = false,
    this.reportAlternateKeys = false,
    this.reportAllKeysAsEscapeCodes = false,
    this.reportAssociatedText = false,
  });

  /// Creates from [KeyboardEnhancementFlagsEvent].
  factory KeyboardFlags.fromEvent(KeyboardEnhancementFlagsEvent event) => KeyboardFlags(
    disambiguateEscapeCodes: event.has(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes),
    reportEventTypes: event.has(KeyboardEnhancementFlagsEvent.reportEventTypes),
    reportAlternateKeys: event.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys),
    reportAllKeysAsEscapeCodes: event.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes),
    reportAssociatedText: event.has(KeyboardEnhancementFlagsEvent.reportAssociatedText),
  );

  @override
  String toString() =>
      'KeyboardFlags('
      'disambiguateEscapeCodes: $disambiguateEscapeCodes, '
      'reportEventTypes: $reportEventTypes, '
      'reportAlternateKeys: $reportAlternateKeys, '
      'reportAllKeysAsEscapeCodes: $reportAllKeysAsEscapeCodes, '
      'reportAssociatedText: $reportAssociatedText)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyboardFlags &&
          other.disambiguateEscapeCodes == disambiguateEscapeCodes &&
          other.reportEventTypes == reportEventTypes &&
          other.reportAlternateKeys == reportAlternateKeys &&
          other.reportAllKeysAsEscapeCodes == reportAllKeysAsEscapeCodes &&
          other.reportAssociatedText == reportAssociatedText);

  @override
  int get hashCode => Object.hash(
    disambiguateEscapeCodes,
    reportEventTypes,
    reportAlternateKeys,
    reportAllKeysAsEscapeCodes,
    reportAssociatedText,
  );
}

/// Unicode Core status.
enum UnicodeCoreStatus {
  /// Unicode Core is enabled.
  enabled,

  /// Unicode Core is disabled.
  disabled,

  /// Status is unknown.
  unknown,
}

/// In-band window resize status.
enum InBandResizeStatus {
  /// In-band resize is supported and enabled.
  enabled,

  /// In-band resize is supported but disabled.
  disabled,

  /// Status is unknown or unsupported.
  unknown,
}

/// Bracketed paste status.
enum BracketedPasteStatus {
  /// Bracketed paste is supported and enabled.
  enabled,

  /// Bracketed paste is supported but disabled.
  disabled,

  /// Status is unknown or unsupported.
  unknown,
}

/// Window size in pixels.
@immutable
class WindowSize {
  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Creates a window size.
  const WindowSize(this.width, this.height);

  /// Creates from [QueryTerminalWindowSizeEvent].
  factory WindowSize.fromEvent(QueryTerminalWindowSizeEvent event) => WindowSize(event.width, event.height);

  @override
  String toString() => 'WindowSize($width, $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is WindowSize && other.width == width && other.height == height);

  @override
  int get hashCode => Object.hash(width, height);
}

/// Builder for constructing TermInfo during probe.
class TermInfoBuilder {
  final Map<ProbeQuery, QueryResult<Object>> _results = {};

  /// Sets a query result.
  void set<T extends Object>(ProbeQuery query, QueryResult<T> result) {
    _results[query] = result;
  }

  /// Builds immutable TermInfo from collected results.
  TermInfo build() => TermInfo._(Map<ProbeQuery, QueryResult<Object>>.unmodifiable(_results));
}

/// Terminal capability information from probeTerminal().
///
/// This is an immutable data class containing probe results. Obtain via
/// `probeTerminal` function. Use typed getters to access query results.
/// Each returns [Supported] on success, or [Unavailable] on failure/skip.
@immutable
class TermInfo {
  final Map<ProbeQuery, QueryResult<Object>> _results;

  /// Creates TermInfo from probe results. Internal constructor.
  const TermInfo._(this._results);

  /// Device identification from DA1 query.
  QueryResult<DeviceAttributes> get deviceAttrs =>
      _results[ProbeQuery.deviceAttrs] as QueryResult<DeviceAttributes>? ??
      const Unavailable(UnavailableReason.skipped);

  /// Terminal name and version.
  QueryResult<String> get terminalVersion =>
      _results[ProbeQuery.terminalVersion] as QueryResult<String>? ?? const Unavailable(UnavailableReason.skipped);

  /// Terminal foreground color.
  QueryResult<Color> get foregroundColor =>
      _results[ProbeQuery.foregroundColor] as QueryResult<Color>? ?? const Unavailable(UnavailableReason.skipped);

  /// Terminal background color.
  QueryResult<Color> get backgroundColor =>
      _results[ProbeQuery.backgroundColor] as QueryResult<Color>? ?? const Unavailable(UnavailableReason.skipped);

  /// Sync update capability.
  QueryResult<SyncUpdateStatus> get syncUpdate =>
      _results[ProbeQuery.syncUpdate] as QueryResult<SyncUpdateStatus>? ?? const Unavailable(UnavailableReason.skipped);

  /// Keyboard enhancement capabilities.
  /// [Supported] implies enhanced keyboard available.
  QueryResult<KeyboardFlags> get keyboardCapabilities =>
      _results[ProbeQuery.keyboardCapabilities] as QueryResult<KeyboardFlags>? ??
      const Unavailable(UnavailableReason.skipped);

  /// Unicode Core capability.
  QueryResult<UnicodeCoreStatus> get unicodeCore =>
      _results[ProbeQuery.unicodeCore] as QueryResult<UnicodeCoreStatus>? ??
      const Unavailable(UnavailableReason.skipped);

  /// Window size in pixels.
  QueryResult<WindowSize> get windowSizePixels =>
      _results[ProbeQuery.windowSizePixels] as QueryResult<WindowSize>? ?? const Unavailable(UnavailableReason.skipped);

  /// Color scheme (light/dark mode).
  QueryResult<ColorSchemeMode> get colorScheme =>
      _results[ProbeQuery.colorScheme] as QueryResult<ColorSchemeMode>? ?? const Unavailable(UnavailableReason.skipped);

  /// In-band window resize reporting capability.
  QueryResult<InBandResizeStatus> get inBandResize =>
      _results[ProbeQuery.inBandResize] as QueryResult<InBandResizeStatus>? ??
      const Unavailable(UnavailableReason.skipped);

  /// Bracketed paste reporting capability.
  QueryResult<BracketedPasteStatus> get bracketedPaste =>
      _results[ProbeQuery.bracketedPaste] as QueryResult<BracketedPasteStatus>? ??
      const Unavailable(UnavailableReason.skipped);

  /// Whether the terminal advertises OSC 52 clipboard support via DA1 (param 52).
  ///
  /// Derived from [deviceAttrs] — non-intrusive (no clipboard popup or timeout,
  /// unlike querying OSC 52 directly). [Supported] carries `true`/`false` for
  /// param present/absent; if DA1 itself was unavailable, that reason is
  /// propagated. Note: `52` certifies clipboard *write* only (the terminal must
  /// also permit it); clipboard *read* stays terminal-gated and is not implied.
  QueryResult<bool> get clipboardOsc52 => _deviceAttrFlag(DeviceAttributeParams.clipboard);

  /// Whether the terminal advertises Sixel graphics via DA1 (param 4).
  ///
  /// Derived from [deviceAttrs]; see [clipboardOsc52] for the result semantics.
  QueryResult<bool> get sixelGraphics => _deviceAttrFlag(DeviceAttributeParams.sixelGraphics);

  /// Maps [deviceAttrs] to a boolean capability flag for DA1 param [p].
  QueryResult<bool> _deviceAttrFlag(DeviceAttributeParams p) => switch (deviceAttrs) {
    Supported(:final value) => Supported(value.params.contains(p)),
    Unavailable(:final reason) => Unavailable(reason),
    Pending() => const Pending(),
  };
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
