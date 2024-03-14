import 'package:equatable/equatable.dart';
import 'package:termansi/termansi.dart' as ansi;

import './profile.dart';
import 'shared/color_util.dart';
import 'shared/int_extension.dart';
import 'shared/string_extension.dart';

const _foreground = 38;
const _background = 48;

/// Color is the base class for all colors.
sealed class Color {
  /// The profile of the color.
  final ProfileEnum profile;

  /// Creates a new Color.
  const Color(this.profile);

  /// Returns the ANSI sequence for the given color.
  String sequence({bool background = false});
}

/// NoColor is a color representation when the terminal does not support colors.
class NoColor implements Color {
  /// Creates a new NoColor.
  const NoColor();

  @override
  ProfileEnum get profile => ProfileEnum.noColor;

  @override
  String sequence({bool background = false}) => '';

  @override
  String toString() => '';
}

/// Color (0-15) as defined by the ANSI Standard.
class Ansi16Color extends Equatable implements Color {
  /// The color value.
  late final int code;

  /// Creates a new Ansi16Color with the given color value.
  Ansi16Color(int color) {
    if (color < 0 || color > 15) throw ArgumentError.value(color, 'color', 'Must be between 0 and 15');
    code = color;
  }

  /// Returns the color's profile. For all the colors from this class is [ProfileEnum.ansi16].
  @override
  ProfileEnum get profile => ProfileEnum.ansi16;

  @override
  String sequence({bool background = false}) {
    if (code < 8) {
      return '${background ? code + 10 + 30 : code + 30}';
    }
    return '${background ? code + 90 + 10 - 8 : code + 90 - 8}';
  }

  @override
  String toString() => code.toString();

  /// @nodoc
  @override
  List<Object?> get props => [code];

  /// @nodoc
  @override
  bool get stringify => false;
}

/// Color (0-255) as defined by the ANSI Standard.
class Ansi256Color extends Equatable implements Color {
  /// The color value.
  late final int code;

  /// Creates a new Ansi256Color with the given color value.
  Ansi256Color(int color) {
    if (color < 0 || color > 255) throw ArgumentError.value(color, 'color', 'Must be between 0 and 255');
    code = color;
  }

  @override
  ProfileEnum get profile => ProfileEnum.ansi256;

  @override
  String sequence({bool background = false}) {
    return '${background ? _background : _foreground};5;$code';
  }

  @override
  String toString() => code.toString();

  /// Converts an ANSI 256 color to an ANSI 16 color.
  Ansi16Color toAnsi16Color() {
    final tc256 = TrueColor.fromString(ansi.ansiHex[code]);
    var minDistance = double.maxFinite;
    var index = 0;
    for (var i = 0; i < 16; i++) {
      final distance = tc256.rgbDistance(TrueColor.fromString(ansi.ansiHex[i]));
      if (distance < minDistance) {
        minDistance = distance;
        index = i;
      }
    }
    return Ansi16Color(index);
  }

  /// @nodoc
  @override
  List<Object?> get props => [code];

  /// @nodoc
  @override
  bool get stringify => false;
}

/// Represents a true color with RGB values.
class TrueColor extends Equatable implements Color {
  /// The red value.
  late final int r;

  /// The green value.
  late final int g;

  /// The blue value.
  late final int b;

  /// String that represents the color in hexadecimal notation. ex: #DECAF0
  late final String hex;

  /// Creates a new TrueColor with the given RGB values.
  TrueColor(int red, int green, int blue) {
    if (red < 0 || red > 255) throw ArgumentError.value(red, 'red', 'Must be between 0 and 255');
    if (green < 0 || green > 255) throw ArgumentError.value(green, 'green', 'Must be between 0 and 255');
    if (blue < 0 || blue > 255) throw ArgumentError.value(blue, 'blue', 'Must be between 0 and 255');

    r = red;
    g = green;
    b = blue;

    hex = '#${red.hex2}${green.hex2}${blue.hex2}';
  }

  @override
  ProfileEnum get profile => ProfileEnum.trueColor;

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

  /// @nodoc
  @override
  List<Object?> get props => [r, g, b, hex];

  /// @nodoc
  @override
  bool get stringify => false;
}
