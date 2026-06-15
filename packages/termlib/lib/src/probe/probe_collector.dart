import 'dart:async';

import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';

import 'term_info.dart';

/// Collects batched probe replies, routing each terminal response to the
/// [ProbeQuery] slot it answers and completing [done] when the DA1 fence lands.
///
/// Installed as a tap on the parser event source for the duration of a batch
/// probe. Each wanted reply is matched to its query by type — or, for the
/// otherwise-identical fg/bg color replies, by
/// [ColorQueryEvent.code] (10 = foreground, 11 = background). Anything else is
/// left for the normal event queue.
///
/// Correctness depends on matching replies by type/content, not by arrival
/// order; the DA1 fence ([ProbeQuery.deviceAttrs]) only provides the early-exit
/// optimization via [done].
@internal
final class ProbeCollector {
  /// The queries whose replies this collector consumes.
  ///
  /// Always contains [ProbeQuery.deviceAttrs]: DA1 is both a probe target and
  /// the fence, so it is wanted even when the caller skips it.
  final Set<ProbeQuery> wanted;

  /// Replies collected so far, slotted by the query they answer.
  final Map<ProbeQuery, ResponseEvent> results = {};

  final Completer<void> _done = Completer<void>();

  /// Creates a collector for [wanted]; [ProbeQuery.deviceAttrs] is always added
  /// as the fence even when the caller skips it.
  ProbeCollector(Set<ProbeQuery> wanted) : wanted = {...wanted, ProbeQuery.deviceAttrs};

  /// Completes when the DA1 fence reply arrives (early-exit) — never with an
  /// error. The batch driver races this against the batch deadline.
  Future<void> get done => _done.future;

  /// Offers a parsed [event] to the collector.
  ///
  /// Returns `true` when [event] is a wanted probe reply (consumed; the caller
  /// must not enqueue it). Returns `false` for strays and replies to queries we
  /// did not ask for, so the caller routes them to the normal event queue.
  ///
  /// Duplicate replies for an already-filled slot are consumed but ignored.
  /// The DA1 fence completes [done] the first time it is seen.
  bool offer(Event event) {
    final slot = _classify(event);
    if (slot == null || !wanted.contains(slot)) return false;

    results.putIfAbsent(slot, () => event as ResponseEvent);

    if (slot == ProbeQuery.deviceAttrs && !_done.isCompleted) {
      _done.complete();
    }

    return true;
  }

  /// Maps a parsed [event] to the [ProbeQuery] it answers, or `null` when it is
  /// not a recognized probe reply. Only the fg/bg colors are matched by content.
  static ProbeQuery? _classify(Event event) => switch (event) {
    PrimaryDeviceAttributesEvent() => ProbeQuery.deviceAttrs,
    NameAndVersionEvent() => ProbeQuery.terminalVersion,
    ColorQueryEvent(:final code) when code == 10 => ProbeQuery.foregroundColor,
    ColorQueryEvent(:final code) when code == 11 => ProbeQuery.backgroundColor,
    QuerySyncUpdateEvent() => ProbeQuery.syncUpdate,
    KeyboardEnhancementFlagsEvent() => ProbeQuery.keyboardCapabilities,
    QueryTerminalWindowSizeEvent() => ProbeQuery.windowSizePixels,
    UnicodeCoreEvent() => ProbeQuery.unicodeCore,
    ColorSchemeEvent() => ProbeQuery.colorScheme,
    QueryWindowResizeEvent() => ProbeQuery.inBandResize,
    QueryBracketedPasteEvent() => ProbeQuery.bracketedPaste,
    _ => null,
  };
}
