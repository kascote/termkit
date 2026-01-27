import 'package:termparser/termparser_events.dart';

import '../colors.dart';
import '../termlib_base.dart';
import 'query_result.dart';
import 'raw_queries.dart';
import 'term_info.dart';

/// Probe terminal capabilities.
///
/// Runs sequential queries to detect terminal capabilities. Returns a [TermInfo]
/// with detected capabilities.
///
/// Parameters:
/// - [term]: The terminal to probe
/// - [skip]: Queries to skip (default: none)
/// - [timeout]: Timeout in milliseconds for each query (default: 500)
///
/// Throws [StateError] if terminal is non-interactive (!hasTerminal).
///
/// Example:
/// ```dart
/// final term = TermLib();
/// final info = await probeTerminal(term);
/// if (info.syncUpdate case Supported(:final value)) {
///   print('Sync updates: $value');
/// }
/// ```
Future<TermInfo> probeTerminal(
  TermLib term, {
  Set<ProbeQuery> skip = const {},
  int timeout = 500,
}) async {
  if (!term.hasTerminal) {
    throw StateError('probeTerminal() requires interactive terminal');
  }

  final builder = TermInfoBuilder();

  // Mark skipped queries with proper typed Unavailable
  void markSkipped(ProbeQuery q) {
    switch (q) {
      case ProbeQuery.deviceAttrs:
        builder.set(q, const Unavailable<DeviceAttributes>(UnavailableReason.skipped));
      case ProbeQuery.terminalVersion:
        builder.set(q, const Unavailable<String>(UnavailableReason.skipped));
      case ProbeQuery.foregroundColor:
        builder.set(q, const Unavailable<Color>(UnavailableReason.skipped));
      case ProbeQuery.backgroundColor:
        builder.set(q, const Unavailable<Color>(UnavailableReason.skipped));
      case ProbeQuery.syncUpdate:
        builder.set(q, const Unavailable<SyncUpdateStatus>(UnavailableReason.skipped));
      case ProbeQuery.keyboardCapabilities:
        builder.set(q, const Unavailable<KeyboardFlags>(UnavailableReason.skipped));
      case ProbeQuery.windowSizePixels:
        builder.set(q, const Unavailable<WindowSize>(UnavailableReason.skipped));
      case ProbeQuery.unicodeCore:
        builder.set(q, const Unavailable<UnicodeCoreStatus>(UnavailableReason.skipped));
      case ProbeQuery.colorScheme:
        builder.set(q, const Unavailable<ColorSchemeMode>(UnavailableReason.skipped));
    }
  }

  skip.forEach(markSkipped);

  await term.withRawModeAsync(() async {
    if (!skip.contains(ProbeQuery.deviceAttrs)) {
      final e = await term.rawQueryDeviceAttrs(timeout);
      builder.set(
        ProbeQuery.deviceAttrs,
        e != null
            ? Supported(DeviceAttributes.fromEvent(e))
            : const Unavailable<DeviceAttributes>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.terminalVersion)) {
      final e = await term.rawQueryTerminalVersion(timeout);
      builder.set(
        ProbeQuery.terminalVersion,
        e != null ? Supported(e.value) : const Unavailable<String>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.foregroundColor)) {
      final e = await term.rawQueryColor(10, timeout);
      builder.set(
        ProbeQuery.foregroundColor,
        e != null
            ? Supported(Color.fromRGBComponent(e.r, e.g, e.b))
            : const Unavailable<Color>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.backgroundColor)) {
      final e = await term.rawQueryColor(11, timeout);
      builder.set(
        ProbeQuery.backgroundColor,
        e != null
            ? Supported(Color.fromRGBComponent(e.r, e.g, e.b))
            : const Unavailable<Color>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.syncUpdate)) {
      final e = await term.rawQuerySyncUpdateStatus(timeout);
      builder.set(
        ProbeQuery.syncUpdate,
        e != null ? Supported(_mapSyncStatus(e)) : const Unavailable<SyncUpdateStatus>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.keyboardCapabilities)) {
      final e = await term.rawQueryKeyboardFlags(timeout);
      builder.set(
        ProbeQuery.keyboardCapabilities,
        e != null ? Supported(KeyboardFlags.fromEvent(e)) : const Unavailable<KeyboardFlags>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.windowSizePixels)) {
      final e = await term.rawQueryWindowSizePixels(timeout);
      builder.set(
        ProbeQuery.windowSizePixels,
        e != null ? Supported(WindowSize.fromEvent(e)) : const Unavailable<WindowSize>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.unicodeCore)) {
      final e = await term.rawQueryUnicodeCoreStatus(timeout);
      builder.set(
        ProbeQuery.unicodeCore,
        e != null ? Supported(_mapUnicodeStatus(e)) : const Unavailable<UnicodeCoreStatus>(UnavailableReason.timeout),
      );
    }

    if (!skip.contains(ProbeQuery.colorScheme)) {
      final e = await term.rawQueryColorScheme(timeout);
      builder.set(
        ProbeQuery.colorScheme,
        e != null ? Supported(e.mode) : const Unavailable<ColorSchemeMode>(UnavailableReason.timeout),
      );
    }
  });

  return builder.build();
}

SyncUpdateStatus _mapSyncStatus(QuerySyncUpdateEvent e) {
  return switch (e.status) {
    DECRPMStatus.enabled || DECRPMStatus.permanentlyEnabled => SyncUpdateStatus.enabled,
    DECRPMStatus.disabled || DECRPMStatus.permanentlyDisabled => SyncUpdateStatus.disabled,
    _ => SyncUpdateStatus.unknown,
  };
}

UnicodeCoreStatus _mapUnicodeStatus(UnicodeCoreEvent e) {
  return switch (e.status) {
    DECRPMStatus.enabled || DECRPMStatus.permanentlyEnabled => UnicodeCoreStatus.enabled,
    DECRPMStatus.disabled || DECRPMStatus.permanentlyDisabled => UnicodeCoreStatus.disabled,
    _ => UnicodeCoreStatus.unknown,
  };
}
