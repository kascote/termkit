import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;

import '../color_util.dart';
import './termlib_base.dart';
import 'shared/color_util.dart';
import 'shared/int_extension.dart';
import 'shared/string_extension.dart';

const _foreground = 38;
const _background = 48;
const _resetFg = 39;
const _resetBg = 49;

// Keeps a cache for the colors requested/converted by the user to save time.
// Over time this cache must be short, because the there are no many colors
// that a terminal program will use
Map<(ProfileEnum, Color), Color> _colorCache = {};

/// Color is the base class for all colors.
sealed class Color {
  /// The profile of the color.
  final ProfileEnum profile;

  /// Creates a new Color.
  factory Color(String color, {Color defaultColor = const NoColor()}) {
    if (color.isEmpty) return defaultColor;

    final mix = ansi.x11Colors[color] ?? color;
    Color c;
    if (mix.startsWith('#')) {
      c = TrueColor.fromString(mix);
    } else {
      final colNum = int.tryParse(mix);
      if (colNum == null) {
        c = defaultColor;
      } else {
        c = (colNum < 16 ? Ansi16Color(colNum) : Ansi256Color(colNum));
      }
    }

    return c;
  }

  /// Returns true if the color is a reset color.
  bool get isReset => switch (this) { Ansi16Color(:final code) => code == _resetFg || code == _resetBg, _ => false };

  const Color._(this.profile);

  /// Returns the ANSI sequence for the given color.
  /// If [background] is true, the sequence will be for the background color.
  String sequence({bool background = false});

  /// Converts a color from the current profile to another profile.
  Color convert(ProfileEnum toProfile) {
    final cache = _colorCache[(toProfile, this)];
    if (cache != null) return cache;

    if (toProfile == ProfileEnum.noColor || profile == ProfileEnum.noColor) return const NoColor();
    if (toProfile == profile) return this;

    Color convertFromTrueColor() {
      return switch (toProfile) {
        ProfileEnum.ansi16 => (this as TrueColor).toAnsi16Color(),
        ProfileEnum.ansi256 => (this as TrueColor).toAnsi256Color(),
        _ => this,
      };
    }

    Color convertToTrueColor() {
      return switch (profile) {
        ProfileEnum.ansi16 => TrueColor.fromString(ansi.ansiHex[(this as Ansi16Color).code]),
        ProfileEnum.ansi256 => TrueColor.fromString(ansi.ansiHex[(this as Ansi256Color).code]),
        _ => this
      };
    }

    final result = switch (toProfile) {
      ProfileEnum.noColor => const NoColor(),
      ProfileEnum.ansi16 =>
        profile == ProfileEnum.ansi256 ? (this as Ansi256Color).toAnsi16Color() : convertFromTrueColor(),
      ProfileEnum.ansi256 =>
        profile == ProfileEnum.ansi16 ? Ansi256Color((this as Ansi16Color).code) : convertFromTrueColor(),
      ProfileEnum.trueColor => convertToTrueColor()
    };

    _colorCache[(toProfile, this)] = result;
    return result;
  }

  /// Clears the color cache.
  void clearColorCache() => _colorCache.clear();

  // whe can not add static methods to extension classes
  // and that the static method be part of the extended class
  /// Returns black color on ANSI 16 profile
  static Color get black => Ansi16Color(0);

  /// Returns red color on ANSI 16 profile
  static Color get red => Ansi16Color(1);

  /// Returns green color on ANSI 16 profile
  static Color get green => Ansi16Color(2);

  /// Returns yellow color on ANSI 16 profile
  static Color get yellow => Ansi16Color(3);

  /// Returns blue color on ANSI 16 profile
  static Color get blue => Ansi16Color(4);

  /// Returns magenta color on ANSI 16 profile
  static Color get magenta => Ansi16Color(5);

  /// Returns cyan color on ANSI 16 profile
  static Color get cyan => Ansi16Color(6);

  /// Returns white color on ANSI 16 profile
  static Color get white => Ansi16Color(7);

  /// Returns bright black color on ANSI 16 profile
  static Color get brightBlack => Ansi16Color(8);

  /// Returns bright red color on ANSI 16 profile
  static Color get brightRed => Ansi16Color(9);

  /// Returns bright green color on ANSI 16 profile
  static Color get brightGreen => Ansi16Color(10);

  /// Returns bright yellow color on ANSI 16 profile
  static Color get brightYellow => Ansi16Color(11);

  /// Returns bright blue color on ANSI 16 profile
  static Color get brightBlue => Ansi16Color(12);

  /// Returns bright magenta color on ANSI 16 profile
  static Color get brightMagenta => Ansi16Color(13);

  /// Returns bright cyan color on ANSI 16 profile
  static Color get brightCyan => Ansi16Color(14);

  /// Returns bright white color on ANSI 16 profile
  static Color get brightWhite => Ansi16Color(15);

  /// Reset the foreground color to default
  static Color get resetFg => Ansi16Color(_resetFg);

  /// Reset the background color to default
  static Color get resetBg => Ansi16Color(_resetBg);
}

/// NoColor is a color representation when the terminal does not support colors.
class NoColor extends Color {
  /// Creates a new NoColor.
  const NoColor() : super._(ProfileEnum.noColor);

  @override
  String sequence({bool background = false}) => '';

  @override
  String toString() => '';
}

/// Color (0-15) as defined by the ANSI Standard.
@immutable
class Ansi16Color extends Color {
  /// The color value.
  late final int code;

  /// Creates a new Ansi16Color with the given color value.
  Ansi16Color(int color) : super._(ProfileEnum.ansi16) {
    if ((color != _resetFg && color != _resetBg) && (color < 0 || color > 15)) {
      throw ArgumentError.value(color, 'color', 'Must be between 0 and 15');
    }
    code = color;
  }

  @override
  String sequence({bool background = false}) {
    if (code < 8) {
      return '${background ? code + 10 + 30 : code + 30}';
    }
    if (code == _resetFg || code == _resetBg) {
      return '${background ? _resetBg : _resetFg}';
    }
    return '${background ? code + 90 + 10 - 8 : code + 90 - 8}';
  }

  @override
  String toString() => code.toString();

  @override
  bool operator ==(Object other) => other is Ansi16Color && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Color (0-255) as defined by the ANSI Standard.
@immutable
class Ansi256Color extends Color {
  /// The color value.
  late final int code;

  /// Creates a new Ansi256Color with the given color value.
  Ansi256Color(int color) : super._(ProfileEnum.ansi256) {
    if (color < 0 || color > 255) throw ArgumentError.value(color, 'color', 'Must be between 0 and 255');
    code = color;
  }

  @override
  String sequence({bool background = false}) {
    return '${background ? _background : _foreground};5;$code';
  }

  @override
  String toString() => code.toString();

  /// Converts an ANSI 256 color to an ANSI 16 color.
  Ansi16Color toAnsi16Color() {
    return switch (code) {
      < 16 => Ansi16Color(code),
      >= 232 && <= 243 => Ansi16Color(0),
      >= 244 && <= 251 => Ansi16Color(7),
      >= 252 => Ansi16Color(15),
      _ => TrueColor.fromString(ansi.ansiHex[code]).toAnsi16Color(),
    };
  }

  /// Convert Ansi256Color to TrueColor
  TrueColor toTrueColor() {
    return TrueColor.fromString(ansi.ansiHex[code]);
  }

  @override
  bool operator ==(Object other) => other is Ansi256Color && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Represents a true color with RGB values.
@immutable
class TrueColor extends Color {
  /// The red value.
  late final int r;

  /// The green value.
  late final int g;

  /// The blue value.
  late final int b;

  /// String that represents the color in hexadecimal notation. ex: #DECAF0
  late final String hex;

  /// Creates a new TrueColor with the given RGB values.
  TrueColor(int red, int green, int blue) : super._(ProfileEnum.trueColor) {
    if (red < 0 || red > 255) throw ArgumentError.value(red, 'red', 'Must be between 0 and 255');
    if (green < 0 || green > 255) throw ArgumentError.value(green, 'green', 'Must be between 0 and 255');
    if (blue < 0 || blue > 255) throw ArgumentError.value(blue, 'blue', 'Must be between 0 and 255');

    r = red;
    g = green;
    b = blue;

    hex = '#${red.hex2}${green.hex2}${blue.hex2}';
  }

  /// Creates a new TrueColor from a string.
  ///
  /// The string can be in the following formats:
  /// - #RGB or RGB
  /// - #RRGGBB or RRGGBB
  /// - x11 color name
  factory TrueColor.fromString(String color) {
    var mix = ansi.x11Colors[color] ?? color;
    if (mix.startsWith('#')) {
      mix = mix.substring(1);
    }
    if (mix.length == 3) {
      final r = mix.substring(0, 1).parseHex();
      final g = mix.substring(1, 2).parseHex();
      final b = mix.substring(2, 3).parseHex();
      return TrueColor(r * 17, g * 17, b * 17);
    }
    if (mix.length == 6) {
      final r = mix.substring(0, 2).parseHex();
      final g = mix.substring(2, 4).parseHex();
      final b = mix.substring(4, 6).parseHex();
      return TrueColor(r, g, b);
    }
    throw ArgumentError.value(mix, 'color', 'Invalid color format');
  }

  /// Returns the TruColor sequence for the given color.
  @override
  String sequence({bool background = false}) {
    return '${background ? _background : _foreground};2;$r;$g;$b';
  }

  @override
  String toString() => hex;

  /// Returns the distance between the current color and the passed one.
  /// The return a value is between 0 and 1. 0 means the colors are identical.
  double rgbDistance(TrueColor color2) {
    return calculateRedMeanDistance(this, color2);
  }

  /// Convert TrueColor to Ansi16Color
  Ansi16Color toAnsi16Color() {
    // final hsv = rgbToHsv(this);
    // final saturation = (hsv.s / 50).round();
    final lum = colorLuminance(this);

    // if (saturation == 0) return Ansi16Color(0);
    if (lum < 0.01) return Ansi16Color(0);

    final ansi = ((b / 255).round() << 2) | ((g / 255).round() << 1) | (r / 255).round();
    // if (saturation == 2) return Ansi16Color(ansi + 8);
    if (lum >= 0.21) return Ansi16Color(ansi + 8);

    return Ansi16Color(ansi);
  }

  /// Convert TrueColor to Ansi256Color
  Ansi256Color toAnsi256Color() {
    if (r >> 4 == g >> 4 && g >> 4 == b >> 4) {
      if (r < 8) {
        return Ansi256Color(16);
      }

      if (r > 248) {
        return Ansi256Color(231);
      }

      return Ansi256Color((((r - 8) / 247) * 24).round() + 232);
    }

    final xr = 36 * (r / 255 * 5).round();
    final xg = 6 * (g / 255 * 5).round();
    final xb = (b / 255 * 5).round();
    final ansi = 16 + xr + xg + xb;

    return Ansi256Color(ansi);
  }

  @override
  bool operator ==(Object other) => other is TrueColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r.hashCode, g.hashCode, b.hashCode);
}
