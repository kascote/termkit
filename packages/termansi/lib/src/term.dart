import './escape_codes.dart';

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
  static String setKeyboardCapabilities(int flags, [int mode = 1]) => '$CSI=$flags;${mode}u';

  /// Push terminal capabilities
  static String pushKeyboardCapabilities(int flags) => '$CSI>${flags}u';

  /// Pop terminal capabilities
  /// entries determine the number of entries to remove from the stack, default 1
  static String popKeyboardCapabilities([int entries = 1]) => '$CSI<${entries}u';

  /// Enable Alternate Screen
  static const String enableAlternateScreen = '$CSI?1049h';

  /// Disable Alternate Screen
  static const String disableAlternateScreen = '$CSI?1049l';

  /// Set Terminal Title
  static String setTerminalTitle(String title) => '${OSC}0;$title$BEL';

  /// Query the terminal for colors settings
  /// reference https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
  static String queryOSCColors(int code) => '$OSC$code;?$ST';

  /// Enable Line Wrapping
  static const String enableLineWrapping = '$CSI?7h';

  /// Disable Line Wrapping
  static const String disableLineWrapping = '$CSI?7l';

  /// Scroll the terminal up a specified number of rows
  static String scrollUp(int rows) => '$CSI${rows}S';

  /// Scroll the terminal down a specified number of rows
  static String scrollDown(int rows) => '$CSI${rows}T';

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
  static const String disableMousePixelsEvents = '$CSI?1000;1003;1016h';

  /// Set Windows size
  ///
  /// Not all terminals support this and not all have this capability enabled
  /// by default could need to be enabled by the user.
  ///
  /// ref: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
  static String setWindowSize(int rows, int cols) => '${CSI}8;$rows;${cols}t';

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
}
