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
  static String get requestKeyboardCapabilities => '$CSI?u';

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
  static String get enableAlternateScreen => '$CSI?1049h';

  /// Disable Alternate Screen
  static String get disableAlternateScreen => '$CSI?1049l';

  /// Set Terminal Title
  static String setTerminalTitle(String title) => '${OSC}0;$title$BEL';

  /// Query the terminal for colors settings
  /// reference https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
  static String queryOSCColors(int code) => '$OSC$code;?$ST';

  /// Enable Line Wrapping
  static String get enableLineWrapping => '$CSI?7h';

  /// Disable Line Wrapping
  static String get disableLineWrapping => '$CSI?7l';

  /// Scroll the terminal up a specified number of rows
  static String scrollUp(int rows) => '$CSI${rows}S';

  /// Scroll the terminal down a specified number of rows
  static String scrollDown(int rows) => '$CSI${rows}T';

  /// Query Sync update status
  ///
  /// https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
  static String get querySyncUpdate => '$CSI?2026\$p';

  /// Start Sync Update
  static String get enableSyncUpdate => '$CSI?2026h';

  /// End Sync Update
  static String get disableSyncUpdate => '$CSI?2026l';

  /// Start receiving focus events
  static String get enableFocusTracking => '$CSI?1004h';

  /// Stop receiving focus events
  static String get disableFocusTracking => '$CSI?1004l';

  /// Request terminal name and version
  static String get requestTermVersion => '$CSI>0q';

  /// Start receiving mouse events
  static String get enableMouseEvents => '$CSI?1000;1003;1006h';

  /// Stop receiving mouse events
  static String get disableMouseEvents => '$CSI?1000;1003;1006l';

  /// Start receiving mouse events inside default configuration zellij multiplexer
  static String get enableZellijMouseEvents => _mouseModeCode(true);

  /// Stop receiving mouse events inside default configuration zellij multiplexer
  static String get disableZellijMouseEvents => _mouseModeCode(false);

  /// Start receiving mouse events as pixels
  static String get enableMousePixelEvents => '$CSI?1000;1003;1016h';

  /// Stop receiving mouse events as pixels
  static String get disableMousePixelsEvents => '$CSI?1000;1003;1016h';

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
  static String get minimizeWindow => '${CSI}2t';

  /// Maximize terminal window
  ///
  /// Not all terminals support this and not all have this capability enabled
  /// by default could need to be enabled by the user
  static String get maximizeWindow => '${CSI}1t';

  /// Query Progressive Keyboard Enhancement (Kitty protocol)
  static String get queryKeyboardEnhancementSupport => '$CSI?u';

  /// Query Primary Device Attributes
  static String get queryPrimaryDeviceAttributes => '${CSI}c';

// soft terminal reset
// CSI ! p
// read window size in pixels
// CSI 14 t
}

String _mouseModeCode(bool value) => '$CSI?1000;1002;1003;1006;1015${value ? 'h' : 'l'}';
