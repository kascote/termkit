import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser_events.dart';

import '../colors.dart';
import '../termlib_base.dart';
import 'probe_collector.dart';
import 'query_result.dart';
import 'term_info.dart';

/// Probe terminal capabilities.
///
/// Fires **all** wanted query escapes in a single batch (with DA1 last as the
/// fence), then collects replies until the DA1 reply lands (early-exit) or the
/// batch [deadline] elapses.
///
/// Parameters:
/// - [term]: The terminal to probe
/// - [skip]: Queries to skip (default: none). DA1 is still sent for fencing even
///   when [ProbeQuery.deviceAttrs] is skipped, but its result is discarded.
/// - [deadline]: Whole-batch deadline in milliseconds (default: 500). The silent
///   path now costs ~one deadline rather than `N × timeout`, so it can be
///   generous.
///
/// Example:
/// ```dart
/// final term = Term.open();
/// if (term is! InteractiveTerm) return;
/// final info = await probeTerminal(term);
/// if (info.syncUpdate case Supported(:final value)) {
///   print('Sync updates: $value');
/// }
/// ```
Future<TermInfo> probeTerminal(
  InteractiveTerm term, {
  Set<ProbeQuery> skip = const {},
  int deadline = 500,
}) async {
  // DA1 is always wanted: it is both a probe target and the fence (§3).
  final wanted = ProbeQuery.values.toSet()
    ..removeAll(skip)
    ..add(ProbeQuery.deviceAttrs);
  final collector = ProbeCollector(wanted);

  await term.withModes(rawMode: true, () async {
    await term.runProbeBatch(_buildBatch(wanted), collector, Duration(milliseconds: deadline));
  });

  final builder = TermInfoBuilder();
  for (final q in ProbeQuery.values) {
    _mapResult(builder, q, skip, collector.results);
  }
  return builder.build();
}

/// Concatenates the escape for every wanted query except DA1, then appends DA1
/// (`CSI c`) **last** so it fences the batch (§3).
String _buildBatch(Set<ProbeQuery> wanted) {
  final buffer = StringBuffer();
  for (final q in ProbeQuery.values) {
    if (q == ProbeQuery.deviceAttrs || !wanted.contains(q)) continue;
    buffer.write(_escapeFor(q));
  }
  buffer.write(ansi.Term.queryPrimaryDeviceAttributes);
  return buffer.toString();
}

/// The query escape sequence for [q].
String _escapeFor(ProbeQuery q) => switch (q) {
  ProbeQuery.deviceAttrs => ansi.Term.queryPrimaryDeviceAttributes,
  ProbeQuery.terminalVersion => ansi.Term.requestTermVersion,
  ProbeQuery.foregroundColor => ansi.Term.queryOSCColors(10),
  ProbeQuery.backgroundColor => ansi.Term.queryOSCColors(11),
  ProbeQuery.syncUpdate => ansi.Term.querySyncUpdate,
  ProbeQuery.keyboardCapabilities => ansi.Term.requestKeyboardCapabilities,
  ProbeQuery.windowSizePixels => ansi.Term.queryWindowSizePixels,
  ProbeQuery.unicodeCore => ansi.Term.queryUnicodeCore,
  ProbeQuery.colorScheme => ansi.Term.queryColorScheme,
  ProbeQuery.inBandResize => ansi.Term.queryInBandResize,
  ProbeQuery.bracketedPaste => ansi.Term.queryBracketedPaste,
};

/// Maps a collected reply (or its absence) into a typed [QueryResult] and stores
/// it on [builder]. Three outcomes: skipped → `Unavailable(skipped)`; reply
/// present → `Supported(mapped)`; no reply → `Unavailable(timeout)`.
void _mapResult(
  TermInfoBuilder builder,
  ProbeQuery q,
  Set<ProbeQuery> skip,
  Map<ProbeQuery, ResponseEvent> results,
) {
  QueryResult<T> outcome<T extends Object, E extends ResponseEvent>(T Function(E) map) {
    if (skip.contains(q)) return const Unavailable(UnavailableReason.skipped);
    final e = results[q];
    if (e == null) return const Unavailable(UnavailableReason.timeout);
    return Supported(map(e as E));
  }

  switch (q) {
    case ProbeQuery.deviceAttrs:
      builder.set(q, outcome<DeviceAttributes, PrimaryDeviceAttributesEvent>(DeviceAttributes.fromEvent));
    case ProbeQuery.terminalVersion:
      builder.set(q, outcome<String, NameAndVersionEvent>((e) => e.value));
    case ProbeQuery.foregroundColor:
      builder.set(q, outcome<Color, ColorQueryEvent>((e) => Color.fromRGBComponent(e.r, e.g, e.b)));
    case ProbeQuery.backgroundColor:
      builder.set(q, outcome<Color, ColorQueryEvent>((e) => Color.fromRGBComponent(e.r, e.g, e.b)));
    case ProbeQuery.syncUpdate:
      builder.set(q, outcome<SyncUpdateStatus, QuerySyncUpdateEvent>(_mapSyncStatus));
    case ProbeQuery.keyboardCapabilities:
      builder.set(q, outcome<KeyboardFlags, KeyboardEnhancementFlagsEvent>(KeyboardFlags.fromEvent));
    case ProbeQuery.windowSizePixels:
      builder.set(q, outcome<WindowSize, QueryTerminalWindowSizeEvent>(WindowSize.fromEvent));
    case ProbeQuery.unicodeCore:
      builder.set(q, outcome<UnicodeCoreStatus, UnicodeCoreEvent>(_mapUnicodeStatus));
    case ProbeQuery.colorScheme:
      builder.set(q, outcome<ColorSchemeMode, ColorSchemeEvent>((e) => e.mode));
    case ProbeQuery.inBandResize:
      builder.set(q, outcome<InBandResizeStatus, QueryWindowResizeEvent>(_mapInBandResizeStatus));
    case ProbeQuery.bracketedPaste:
      builder.set(q, outcome<BracketedPasteStatus, QueryBracketedPasteEvent>(_mapBracketedPasteStatus));
  }
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

InBandResizeStatus _mapInBandResizeStatus(QueryWindowResizeEvent e) {
  return switch (e.status) {
    DECRPMStatus.enabled || DECRPMStatus.permanentlyEnabled => InBandResizeStatus.enabled,
    DECRPMStatus.disabled || DECRPMStatus.permanentlyDisabled => InBandResizeStatus.disabled,
    _ => InBandResizeStatus.unknown,
  };
}

BracketedPasteStatus _mapBracketedPasteStatus(QueryBracketedPasteEvent e) {
  return switch (e.status) {
    DECRPMStatus.enabled || DECRPMStatus.permanentlyEnabled => BracketedPasteStatus.enabled,
    DECRPMStatus.disabled || DECRPMStatus.permanentlyDisabled => BracketedPasteStatus.disabled,
    _ => BracketedPasteStatus.unknown,
  };
}
