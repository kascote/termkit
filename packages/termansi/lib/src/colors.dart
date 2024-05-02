import './escape_codes.dart';

/// Terminal color escape sequences
abstract class Color {
  /// Reset
  ///
  /// Will reset all colors and text attributes. Use `default` to reset only colors
  static String get reset => '${CSI}0m';

  /// Black color.
  static String get black => '${CSI}30m';

  /// Red color.
  static String get red => '${CSI}31m';

  /// Green color.
  static String get green => '${CSI}32m';

  /// Yellow color.
  static String get yellow => '${CSI}33m';

  /// Blue color.
  static String get blue => '${CSI}34m';

  /// Magenta color.
  static String get magenta => '${CSI}35m';

  /// Cyan color.
  static String get cyan => '${CSI}36m';

  /// White color.
  static String get white => '${CSI}37m';

  /// Bright black color.
  static String get brightBlack => '${CSI}90m';

  /// Bright red color.
  static String get brightRed => '${CSI}91m';

  /// Bright green color.
  static String get brightGreen => '${CSI}92m';

  /// Bright yellow color.
  static String get brightYellow => '${CSI}93m';

  /// Bright blue color.
  static String get brightBlue => '${CSI}94m';

  /// Bright magenta color.
  static String get brightMagenta => '${CSI}95m';

  /// Bright cyan color.
  static String get brightCyan => '${CSI}96m';

  /// Bright white color.
  static String get brightWhite => '${CSI}97m';

  /// Default Foreground color.
  static String get defaultFg => '${CSI}39m';

  /// Black background.
  static String get blackBg => '${CSI}40m';

  /// Red background.
  static String get redBg => '${CSI}41m';

  /// Green background.
  static String get greenBg => '${CSI}42m';

  /// Yellow background.
  static String get yellowBg => '${CSI}43m';

  /// Blue background.
  static String get blueBg => '${CSI}44m';

  /// Magenta background.
  static String get magentaBg => '${CSI}45m';

  /// Cyan background.
  static String get cyanBg => '${CSI}46m';

  /// White background.
  static String get whiteBg => '${CSI}47m';

  /// Default background color
  static String get defaultBg => '${CSI}49m';

  /// Bright black color.
  static String get brightBlackBg => '${CSI}100m';

  /// Bright red color.
  static String get brightRedBg => '${CSI}101m';

  /// Bright green color.
  static String get brightGreenBg => '${CSI}102m';

  /// Bright yellow color.
  static String get brightYellowBg => '${CSI}103m';

  /// Bright blue color.
  static String get brightBlueBg => '${CSI}104m';

  /// Bright magenta color.
  static String get brightMagentaBg => '${CSI}105m';

  /// Bright cyan color.
  static String get brightCyanBg => '${CSI}106m';

  /// Bright white color.
  static String get brightWhiteBg => '${CSI}107m';

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
  static String get resetUnderlineColor => '${CSI}59m';
}
