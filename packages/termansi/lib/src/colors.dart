import './escape_codes.dart';

/// Terminal color escape sequences
abstract class Color {
  /// Reset
  ///
  /// Will reset all colors and text attributes. Use `default` to reset only colors
  static String reset() => '${CSI}0m';

  /// Black color.
  static String black() => '${CSI}30m';

  /// Red color.
  static String red() => '${CSI}31m';

  /// Green color.
  static String green() => '${CSI}32m';

  /// Yellow color.
  static String yellow() => '${CSI}33m';

  /// Blue color.
  static String blue() => '${CSI}34m';

  /// Magenta color.
  static String magenta() => '${CSI}35m';

  /// Cyan color.
  static String cyan() => '${CSI}36m';

  /// White color.
  static String white() => '${CSI}37m';

  /// Bright black color.
  static String brightBlack() => '${CSI}90m';

  /// Bright red color.
  static String brightRed() => '${CSI}91m';

  /// Bright green color.
  static String brightGreen() => '${CSI}92m';

  /// Bright yellow color.
  static String brightYellow() => '${CSI}93m';

  /// Bright blue color.
  static String brightBlue() => '${CSI}94m';

  /// Bright magenta color.
  static String brightMagenta() => '${CSI}95m';

  /// Bright cyan color.
  static String brightCyan() => '${CSI}96m';

  /// Bright white color.
  static String brightWhite() => '${CSI}97m';

  /// Default Foreground color.
  static String defaultFg() => '${CSI}39m';

  /// Black background.
  static String blackBg() => '${CSI}40m';

  /// Red background.
  static String redBg() => '${CSI}41m';

  /// Green background.
  static String greenBg() => '${CSI}42m';

  /// Yellow background.
  static String yellowBg() => '${CSI}43m';

  /// Blue background.
  static String blueBg() => '${CSI}44m';

  /// Magenta background.
  static String magentaBg() => '${CSI}45m';

  /// Cyan background.
  static String cyanBg() => '${CSI}46m';

  /// White background.
  static String whiteBg() => '${CSI}47m';

  /// Default background color
  static String defaultBg() => '${CSI}49m';

  /// Bright black color.
  static String brightBlackBg() => '${CSI}100m';

  /// Bright red color.
  static String brightRedBg() => '${CSI}101m';

  /// Bright green color.
  static String brightGreenBg() => '${CSI}102m';

  /// Bright yellow color.
  static String brightYellowBg() => '${CSI}103m';

  /// Bright blue color.
  static String brightBlueBg() => '${CSI}104m';

  /// Bright magenta color.
  static String brightMagentaBg() => '${CSI}105m';

  /// Bright cyan color.
  static String brightCyanBg() => '${CSI}106m';

  /// Bright white color.
  static String brightWhiteBg() => '${CSI}107m';

  /// Set 256 color foreground
  static String color256Fg(int color) => '${CSI}38;5;${color}m';

  /// Set 256 color background
  static String color256Bg(int color) => '${CSI}48;5;${color}m';

  /// Foreground True Color
  static String trueColor(int r, int g, int b) => '${CSI}38;2;$r;$g;${b}m';

  /// Background True Color
  static String trueColorBg(int r, int g, int b) => '${CSI}48;2;$r;$g;${b}m';
}
