// Internal query implementations for probe and term extensions.
// NOT exported from termlib.dart - these are implementation details.
//
// These methods don't manage raw mode - caller handles it.

import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser_events.dart';

import '../termlib_base.dart';

/// Internal query implementations.
/// Not part of public API - use term.dart extension methods instead.
extension RawQueries on TermLib {
  /// Query primary device attributes (DA1).
  Future<PrimaryDeviceAttributesEvent?> rawQueryDeviceAttrs(int timeout) async {
    write(ansi.Term.queryPrimaryDeviceAttributes);
    final event = await pollTimeout<PrimaryDeviceAttributesEvent>(timeout: timeout);
    return (event is PrimaryDeviceAttributesEvent) ? event : null;
  }

  /// Query terminal name and version.
  Future<NameAndVersionEvent?> rawQueryTerminalVersion(int timeout) async {
    write(ansi.Term.requestTermVersion);
    final event = await pollTimeout<NameAndVersionEvent>(timeout: timeout);
    return (event is NameAndVersionEvent) ? event : null;
  }

  /// Query OSC color (10=fg, 11=bg).
  Future<ColorQueryEvent?> rawQueryColor(int code, int timeout) async {
    write(ansi.Term.queryOSCColors(code));
    final event = await pollTimeout<ColorQueryEvent>(timeout: timeout);
    return (event is ColorQueryEvent) ? event : null;
  }

  /// Query sync update status.
  Future<QuerySyncUpdateEvent?> rawQuerySyncUpdateStatus(int timeout) async {
    write(ansi.Term.querySyncUpdate);
    final event = await pollTimeout<QuerySyncUpdateEvent>(timeout: timeout);
    return (event is QuerySyncUpdateEvent) ? event : null;
  }

  /// Query keyboard enhancement flags.
  Future<KeyboardEnhancementFlagsEvent?> rawQueryKeyboardFlags(int timeout) async {
    write(ansi.Term.requestKeyboardCapabilities);
    final event = await pollTimeout<KeyboardEnhancementFlagsEvent>(timeout: timeout);
    return (event is KeyboardEnhancementFlagsEvent) ? event : null;
  }

  /// Query window size in pixels.
  Future<QueryTerminalWindowSizeEvent?> rawQueryWindowSizePixels(int timeout) async {
    write(ansi.Term.queryWindowSizePixels);
    final event = await pollTimeout<QueryTerminalWindowSizeEvent>(timeout: timeout);
    return (event is QueryTerminalWindowSizeEvent) ? event : null;
  }

  /// Query Unicode Core status.
  Future<UnicodeCoreEvent?> rawQueryUnicodeCoreStatus(int timeout) async {
    write(ansi.Term.queryUnicodeCore);
    final event = await pollTimeout<UnicodeCoreEvent>(timeout: timeout);
    return (event is UnicodeCoreEvent) ? event : null;
  }

  /// Query color scheme (light/dark mode).
  Future<ColorSchemeEvent?> rawQueryColorScheme(int timeout) async {
    write(ansi.Term.queryColorScheme);
    final event = await pollTimeout<ColorSchemeEvent>(timeout: timeout);
    return (event is ColorSchemeEvent) ? event : null;
  }
}
