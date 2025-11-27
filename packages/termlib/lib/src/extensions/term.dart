import 'dart:convert';

import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

/// Default timeout to wait for terminal query responses.
///
/// This value is used in various query methods in the TermUtils extension
/// to specify how long to wait for a response from the terminal before timing out.
/// If the terminal reply faster, the response will be processed immediately.
const defaultQueryTimeout = 500;

/// Support function that add some extra features to the terminal.
extension TermUtils on TermLib {
  /// Write a hyperlink to the terminal.
  void hyperlink(String link, String name) => write(ansi.Term.hyperLink(link, name));

  /// Write a notification to the terminal.
  void notify(String title, String message) => write(ansi.Term.notify(title, message));

  /// Enable Alternate Screen
  void enableAlternateScreen() => write(ansi.Term.enableAlternateScreen);

  /// Disable Alternate Screen
  void disableAlternateScreen() => write(ansi.Term.disableAlternateScreen);

  /// Set Terminal Title
  void setTerminalTitle(String title) => write(ansi.Term.setTerminalTitle(title));

  /// Start receiving mouse events
  void enableMouseEvents() => write(ansi.Term.enableMouseEvents);

  /// Stop receiving mouse events
  void disableMouseEvents() => write(ansi.Term.disableMouseEvents);

  /// Start receiving focus events
  void startFocusTracking() => write(ansi.Term.enableFocusTracking);

  /// End receiving focus events
  void endFocusTracking() => write(ansi.Term.disableFocusTracking);

  /// Enabled Line Wrapping
  void enableLineWrapping() => write(ansi.Term.enableLineWrapping);

  /// Disabled Line Wrapping
  void disableLineWrapping() => write(ansi.Term.disableLineWrapping);

  /// Scroll the terminal up by the specified number of rows.
  void scrollUp(int rows) => write(ansi.Term.scrollUp(rows));

  /// Scroll the terminal down by the specified number of rows.
  void scrollDown(int rows) => write(ansi.Term.scrollDown(rows));

  /// Start synchronous update mode
  void startSyncUpdate() => write(ansi.Term.enableSyncUpdate);

  /// End synchronous update mode
  void endSyncUpdate() => write(ansi.Term.disableSyncUpdate);

  /// Soft Terminal reset
  void softReset() => write(ansi.Term.softTerminalReset);

  /// Query Sync status
  Future<QuerySyncUpdateEvent?> querySyncUpdate({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<QuerySyncUpdateEvent?>(() async {
      write(ansi.Term.querySyncUpdate);
      final event = await pollTimeout<QuerySyncUpdateEvent>(timeout: timeout);
      return (event is QuerySyncUpdateEvent) ? event : null;
    });
  }

  /// Request terminal name and version
  Future<String> queryTerminalVersion({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<String>(() async {
      write(ansi.Term.requestTermVersion);
      final event = await pollTimeout<NameAndVersionEvent>(timeout: timeout);
      return (event is NameAndVersionEvent) ? event.value : '';
    });
  }

  /// Returns the current terminal status report.
  Future<Color?> queryOSCStatus(int status, {int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<Color?>(() async {
      write(ansi.Term.queryOSCColors(status));
      final event = await pollTimeout<ColorQueryEvent>(timeout: timeout);
      return (event is ColorQueryEvent) ? Color.fromRGBComponent(event.r, event.g, event.b) : null;
    });
  }

  /// Query Keyboard enhancement support
  Future<bool> queryKeyboardEnhancementSupport({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<bool>(() async {
      write(ansi.Term.queryKeyboardEnhancementSupport);
      final event = await pollTimeout<KeyboardEnhancementFlagsEvent>(timeout: timeout);
      return event is KeyboardEnhancementFlagsEvent;
    });
  }

  /// Query Primary Device Attributes
  Future<PrimaryDeviceAttributesEvent?> queryPrimaryDeviceAttributes({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<PrimaryDeviceAttributesEvent?>(() async {
      write(ansi.Term.queryPrimaryDeviceAttributes);
      final event = await pollTimeout<PrimaryDeviceAttributesEvent>(timeout: timeout);
      return (event is PrimaryDeviceAttributesEvent) ? event : null;
    });
  }

  /// Query Terminal window size in pixels
  Future<QueryTerminalWindowSizeEvent?> queryWindowSizeInPixels({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<QueryTerminalWindowSizeEvent?>(() async {
      write(ansi.Term.queryWindowSizePixels);
      final event = await pollTimeout<QueryTerminalWindowSizeEvent>(timeout: timeout);
      return (event is QueryTerminalWindowSizeEvent) ? event : null;
    });
  }

  /// Set Clipboard content
  void clipboardSet(Clipboard clipboard, String data) {
    write(ansi.Term.clipboard(clipboard.target, base64.encode(utf8.encode(data))));
  }

  /// Clear Clipboard contents
  void clipboardClear(Clipboard clipboard) {
    write(ansi.Term.clipboard(clipboard.target, ClipboardMode.clear.mode));
  }

  /// Query Clipboard content
  ///
  /// Note: Most terminals will have this feature disable by default because is
  /// a security risk. Check your terminal for support and how to enable it.
  ///
  /// Can use the timeout parameter to wait for longer time if the terminal
  /// use some interface to request permissions.
  Future<ClipboardCopyEvent?> queryClipboard(Clipboard clipboard, {int timeout = defaultQueryTimeout}) {
    return withRawModeAsync<ClipboardCopyEvent?>(() async {
      write(ansi.Term.clipboard(clipboard.target, ClipboardMode.query.mode));
      final event = await pollTimeout<ClipboardCopyEvent>(timeout: timeout);
      return (event is ClipboardCopyEvent) ? event : null;
    });
  }

  /// Request keyboard capabilities
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  Future<KeyboardEnhancementFlagsEvent?> queryKeyboardCapabilities({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<KeyboardEnhancementFlagsEvent?>(() async {
      write(ansi.Term.requestKeyboardCapabilities);

      final event = await pollTimeout<KeyboardEnhancementFlagsEvent>(timeout: timeout);
      return (event is KeyboardEnhancementFlagsEvent) ? event : null;
    });
  }

  /// Set keyboard flags
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  void setKeyboardFlags(KeyboardEnhancementFlagsEvent flags) =>
      write(ansi.Term.setKeyboardCapabilities(flags.flags, flags.mode));

  /// Push keyboard flags to the stack
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  void pushKeyboardFlags(KeyboardEnhancementFlagsEvent flags) => write(ansi.Term.pushKeyboardCapabilities(flags.flags));

  /// Enable keyboard enhancement
  void enableKeyboardEnhancement() {
    const keyFlags = KeyboardEnhancementFlagsEvent(
      KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes |
          KeyboardEnhancementFlagsEvent.reportAlternateKeys |
          KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes |
          KeyboardEnhancementFlagsEvent.reportEventTypes,
    );
    setKeyboardFlags(keyFlags);
  }

  /// Enable keyboard enhancement with all parameters
  void enableKeyboardEnhancementFull() {
    const keyFlags = KeyboardEnhancementFlagsEvent(
      KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes |
          KeyboardEnhancementFlagsEvent.reportAlternateKeys |
          KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes |
          KeyboardEnhancementFlagsEvent.reportEventTypes |
          KeyboardEnhancementFlagsEvent.reportAssociatedText,
    );
    setKeyboardFlags(keyFlags);
  }

  /// Disable keyboard enhancements
  void disableKeyboardEnhancement() => setKeyboardFlags(const KeyboardEnhancementFlagsEvent(0));

  /// Pop keyboard flags from the stack
  ///
  /// ref: <https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement>
  void popKeyboardFlags([int entries = 1]) => write(ansi.Term.popKeyboardCapabilities(entries));

  /// Enable Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  void enableUnicodeCore() => write(ansi.Term.enableUnicodeCore);

  /// Disable Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  void disableUnicodeCore() => write(ansi.Term.disableUnicodeCore);

  /// Query Unicode Core status
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  Future<UnicodeCoreEvent?> queryUnicodeCore({int timeout = defaultQueryTimeout}) {
    return withRawModeAsync<UnicodeCoreEvent?>(() async {
      write(ansi.Term.queryUnicodeCore);
      final event = await pollTimeout<UnicodeCoreEvent>(timeout: timeout);
      return (event is UnicodeCoreEvent) ? event : null;
    });
  }
}
