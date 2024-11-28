import './escape_codes.dart';

/// Terminal color escape sequences
abstract class Color {
  /// Reset
  ///
  /// Will reset all colors and text attributes. Use `default` to reset only colors
  static const String reset = '${CSI}0m';

  /// Black color.
  static const String black = '${CSI}30m';

  /// Red color.
  static const String red = '${CSI}31m';

  /// Green color.
  static const String green = '${CSI}32m';

  /// Yellow color.
  static const String yellow = '${CSI}33m';

  /// Blue color.
  static const String blue = '${CSI}34m';

  /// Magenta color.
  static const String magenta = '${CSI}35m';

  /// Cyan color.
  static const String cyan = '${CSI}36m';

  /// White color.
  static const String white = '${CSI}37m';

  /// Bright black color.
  static const String brightBlack = '${CSI}90m';

  /// Bright red color.
  static const String brightRed = '${CSI}91m';

  /// Bright green color.
  static const String brightGreen = '${CSI}92m';

  /// Bright yellow color.
  static const String brightYellow = '${CSI}93m';

  /// Bright blue color.
  static const String brightBlue = '${CSI}94m';

  /// Bright magenta color.
  static const String brightMagenta = '${CSI}95m';

  /// Bright cyan color.
  static const String brightCyan = '${CSI}96m';

  /// Bright white color.
  static const String brightWhite = '${CSI}97m';

  /// Default Foreground color.
  static const String defaultFg = '${CSI}39m';

  /// Black background.
  static const String blackBg = '${CSI}40m';

  /// Red background.
  static const String redBg = '${CSI}41m';

  /// Green background.
  static const String greenBg = '${CSI}42m';

  /// Yellow background.
  static const String yellowBg = '${CSI}43m';

  /// Blue background.
  static const String blueBg = '${CSI}44m';

  /// Magenta background.
  static const String magentaBg = '${CSI}45m';

  /// Cyan background.
  static const String cyanBg = '${CSI}46m';

  /// White background.
  static const String whiteBg = '${CSI}47m';

  /// Default background color
  static const String defaultBg = '${CSI}49m';

  /// Bright black color.
  static const String brightBlackBg = '${CSI}100m';

  /// Bright red color.
  static const String brightRedBg = '${CSI}101m';

  /// Bright green color.
  static const String brightGreenBg = '${CSI}102m';

  /// Bright yellow color.
  static const String brightYellowBg = '${CSI}103m';

  /// Bright blue color.
  static const String brightBlueBg = '${CSI}104m';

  /// Bright magenta color.
  static const String brightMagentaBg = '${CSI}105m';

  /// Bright cyan color.
  static const String brightCyanBg = '${CSI}106m';

  /// Bright white color.
  static const String brightWhiteBg = '${CSI}107m';

  /// Set 256 color foreground
  static String color256Fg(int color) => '${CSI}38;5;${color}m';

  /// Set 256 color background
  static String color256Bg(int color) => '${CSI}48;5;${color}m';

  /// Foreground True Color
  static String trueColor(int r, int g, int b) => '${CSI}38;2;$r;$g;${b}m';

  /// Background True Color
  static String trueColorBg(int r, int g, int b) => '${CSI}48;2;$r;$g;${b}m';

  /// Set 256 underline color
  static String underlineColor256(int color) => '${CSI}58;5;${color}m';

  /// Set TrueColor underline color
  static String underlineTrueColor(int r, int g, int b) => '${CSI}58;2;$r;$g;${b}m';

  /// Reset underline color
  static const String resetUnderlineColor = '${CSI}59m';
}
