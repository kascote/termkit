import './escape_codes.dart';

/// Progress bar state for ConEmu OSC 9;4 sequences.
///
/// Used with [Term.setProgress] to display progress in terminal tab
/// and taskbar (Windows Terminal, ConEmu, etc.).
///
/// https://learn.microsoft.com/en-us/windows/terminal/tutorials/progress-bar-sequences
enum ProgressState {
  /// Hidden/default state - clears progress bar (0)
  hidden(0),

  /// Default progress state (1)
  normal(1),

  /// Error state - typically shown in red (2)
  error(2),

  /// Indeterminate state - ignores progress value (3)
  indeterminate(3),

  /// Warning state - typically shown in yellow (4)
  warning(4);

  const ProgressState(this.value);

  /// The numeric value for the escape sequence.
  final int value;
}

/// Support code for terminal output.
abstract class Term {
  /// Show a hyperlink.
  ///
  /// https://github.com/Alhadis/OSC8-Adoption/
  /// https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
  static String hyperLink(String link, String name) => '${OSC}8;;$link$ST$name${OSC}8;;$ST';

  /// Show a notification.
  static String notify(String title, String message) => '${OSC}777;notify;$title;$message$ST';

  /// Request terminal capabilities
  ///
  /// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement
  static const String requestKeyboardCapabilities = '$CSI?u';

  /// Set terminal keyboard capabilities
  ///
  /// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#progressive-enhancement
  static String setKeyboardCapabilities(int flags, [int mode = 1]) {
    assert(flags >= 0, 'flags should be >= 0, got $flags');
    assert(mode >= 0, 'mode should be >= 0, got $mode');
    return '$CSI=$flags;${mode}u';
  }

  /// Push terminal capabilities
  static String pushKeyboardCapabilities(int flags) {
    assert(flags >= 0, 'flags should be >= 0, got $flags');
    return '$CSI>${flags}u';
  }

  /// Pop terminal capabilities
  /// entries determine the number of entries to remove from the stack, default 1
  static String popKeyboardCapabilities([int entries = 1]) {
    assert(entries >= 1, 'entries should be >= 1, got $entries');
    return '$CSI<${entries}u';
  }

  /// Enable Alternate Screen
  static const String enableAlternateScreen = '$CSI?1049h';

  /// Disable Alternate Screen
  static const String disableAlternateScreen = '$CSI?1049l';

  /// Set Terminal Title
  static String setTerminalTitle(String title) => '${OSC}0;$title$BEL';

  /// Query the terminal for colors settings
  /// reference https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
  static String queryOSCColors(int code) {
    assert(code >= 0, 'code should be >= 0, got $code');
    return '$OSC$code;?$ST';
  }

  /// Enable Line Wrapping
  static const String enableLineWrapping = '$CSI?7h';

  /// Disable Line Wrapping
  static const String disableLineWrapping = '$CSI?7l';

  /// Scroll the terminal up a specified number of rows
  static String scrollUp(int rows) {
    assert(rows >= 1, 'rows should be >= 1, got $rows');
    return '$CSI${rows}S';
  }

  /// Scroll the terminal down a specified number of rows
  static String scrollDown(int rows) {
    assert(rows >= 1, 'rows should be >= 1, got $rows');
    return '$CSI${rows}T';
  }

  /// Query Sync update status
  ///
  /// https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
  static const String querySyncUpdate = '$CSI?2026\$p';

  /// Start Sync Update
  static const String enableSyncUpdate = '$CSI?2026h';

  /// End Sync Update
  static const String disableSyncUpdate = '$CSI?2026l';

  /// Start receiving focus events
  static const String enableFocusTracking = '$CSI?1004h';

  /// Stop receiving focus events
  static const String disableFocusTracking = '$CSI?1004l';

  /// Request terminal name and version
  static const String requestTermVersion = '$CSI>0q';

  /// Start receiving mouse events
  static const String enableMouseEvents = '$CSI?1000;1003;1006h';

  /// Stop receiving mouse events
  static const String disableMouseEvents = '$CSI?1000;1003;1006l';

  /// Start receiving mouse events as pixels
  static const String enableMousePixelEvents = '$CSI?1000;1003;1016h';

  /// Stop receiving mouse events as pixels
  static const String disableMousePixelsEvents = '$CSI?1000;1003;1016l';

  /// Set Windows size
  ///
  /// Not all terminals support this and not all have this capability enabled
  /// by default could need to be enabled by the user.
  ///
  /// ref: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
  static String setWindowSize(int rows, int cols) {
    assert(rows >= 1, 'rows should be >= 1, got $rows');
    assert(cols >= 1, 'cols should be >= 1, got $cols');
    return '${CSI}8;$rows;${cols}t';
  }

  /// Minimize terminal window
  ///
  /// Not all terminals support this and not all have this capability enabled
  /// by default could need to be enabled by the user
  static const String minimizeWindow = '${CSI}2t';

  /// Maximize terminal window
  ///
  /// Not all terminals support this and not all have this capability enabled
  /// by default could need to be enabled by the user
  static const String maximizeWindow = '${CSI}1t';

  /// Query Progressive Keyboard Enhancement (Kitty protocol)
  static const String queryKeyboardEnhancementSupport = '$CSI?u';

  /// Query Primary Device Attributes
  static const String queryPrimaryDeviceAttributes = '${CSI}c';

  /// Soft terminal reset
  ///
  /// https://vt100.net/docs/vt510-rm/DECSTR.html
  static const String softTerminalReset = '$CSI!p';

  /// Query window window size in pixels
  static const String queryWindowSizePixels = '${CSI}14t';

  /// Clipboard operations
  ///
  /// [operation] could be one of the followings
  ///	  c: clipboard
  ///	  p: primary
  ///	  q: secondary
  ///	  s: select
  ///	  0-7: cut-buffers
  ///
  /// [data] is the content to be copied to the clipboard as a Base64 encoded
  /// string (RFC-4648)
  ///
  /// If [data] is "?", the terminal replies with the current contents of
  /// the clipboard.
  ///
  /// If [data] is neither a base64 string nor "?", the terminal clears
  /// the clipboard.
  static String clipboard(String operation, String data) => '${OSC}52;$operation;$data$ST';

  /// Enable Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  static const String enableUnicodeCore = '$CSI?2027h';

  /// Disable Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  static const String disableUnicodeCore = '$CSI?2027l';

  /// Query Unicode Core
  ///
  /// ref:  https://github.com/contour-terminal/terminal-unicode-core
  static const String queryUnicodeCore = '$CSI?2027\$p';

  /// Enable Bracketed Paste
  static const String enableBracketedPaste = '$CSI?2004h';

  /// Disable Bracketed Paste
  static const String disableBracketedPaste = '$CSI?2004l';

  /// Set progress bar in terminal tab/taskbar (ConEmu OSC 9;4).
  ///
  /// [state] determines the visual appearance of the progress bar.
  /// [progress] is the percentage (0-100), ignored for [ProgressState.indeterminate].
  ///
  /// Supported by Windows Terminal 1.6+, ConEmu, and compatible terminals.
  ///
  /// ref: https://learn.microsoft.com/en-us/windows/terminal/tutorials/progress-bar-sequences
  static String setProgress(ProgressState state, [int progress = 0]) {
    assert(progress >= 0 && progress <= 100, 'progress should be 0-100, got $progress');
    return '${OSC}9;4;${state.value};$progress$BEL';
  }

  /// Clear/hide progress bar in terminal tab/taskbar.
  ///
  /// Equivalent to `setProgress(ProgressState.hidden, 0)`.
  static const String clearProgress = '${OSC}9;4;0;0$BEL';

  /// Query terminal color scheme preference (light/dark mode).
  ///
  /// Terminal responds with `CSI ? 997 ; Ps n` where Ps indicates the mode.
  ///
  /// ref: https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
  static const String queryColorScheme = '$CSI?996n';

  /// Enable color palette update notifications.
  ///
  /// When enabled, terminal sends unsolicited `CSI ? 997 ; Ps n` when
  /// color scheme changes (OS theme switch or terminal profile change).
  ///
  /// ref: https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
  static const String enableColorPaletteUpdates = '$CSI?2031h';

  /// Disable color palette update notifications.
  ///
  /// ref: https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
  static const String disableColorPaletteUpdates = '$CSI?2031l';
}
