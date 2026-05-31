// Internal query implementations for probe and term extensions.
// NOT exported from termlib.dart - these are implementation details.
//
// These methods don't manage raw mode - caller handles it.

import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser_events.dart';

import '../termlib_base.dart';

/// Internal query implementations.
/// Not part of public API - use term.dart extension methods instead.
@internal
extension RawQueries on InteractiveTerm {
  /// Query primary device attributes (DA1).
  Future<PrimaryDeviceAttributesEvent?> rawQueryDeviceAttrs(int timeout) async {
    write(ansi.Term.queryPrimaryDeviceAttributes);
    return awaitEvent<PrimaryDeviceAttributesEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query terminal name and version.
  Future<NameAndVersionEvent?> rawQueryTerminalVersion(int timeout) async {
    write(ansi.Term.requestTermVersion);
    return awaitEvent<NameAndVersionEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query OSC color (10=fg, 11=bg).
  Future<ColorQueryEvent?> rawQueryColor(int code, int timeout) async {
    write(ansi.Term.queryOSCColors(code));
    return awaitEvent<ColorQueryEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query sync update status.
  Future<QuerySyncUpdateEvent?> rawQuerySyncUpdateStatus(int timeout) async {
    write(ansi.Term.querySyncUpdate);
    return awaitEvent<QuerySyncUpdateEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query keyboard enhancement flags.
  Future<KeyboardEnhancementFlagsEvent?> rawQueryKeyboardFlags(int timeout) async {
    write(ansi.Term.requestKeyboardCapabilities);
    return awaitEvent<KeyboardEnhancementFlagsEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query window size in pixels.
  Future<QueryTerminalWindowSizeEvent?> rawQueryWindowSizePixels(int timeout) async {
    write(ansi.Term.queryWindowSizePixels);
    return awaitEvent<QueryTerminalWindowSizeEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query Unicode Core status.
  Future<UnicodeCoreEvent?> rawQueryUnicodeCoreStatus(int timeout) async {
    write(ansi.Term.queryUnicodeCore);
    return awaitEvent<UnicodeCoreEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query color scheme (light/dark mode).
  Future<ColorSchemeEvent?> rawQueryColorScheme(int timeout) async {
    write(ansi.Term.queryColorScheme);
    return awaitEvent<ColorSchemeEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query in-band window resize status.
  Future<QueryWindowResizeEvent?> rawQueryInBandResize(int timeout) async {
    write(ansi.Term.queryInBandResize);
    return awaitEvent<QueryWindowResizeEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query bracketed paste status.
  Future<QueryBracketedPasteEvent?> rawQueryBracketedPaste(int timeout) async {
    write(ansi.Term.queryBracketedPaste);
    return awaitEvent<QueryBracketedPasteEvent>(timeout: Duration(milliseconds: timeout));
  }

  /// Query cursor position.
  Future<CursorPositionEvent?> rawQueryCursorPosition(int timeout) async {
    write(ansi.Cursor.requestPosition);
    return awaitEvent<CursorPositionEvent>(timeout: Duration(milliseconds: timeout));
  }
}
