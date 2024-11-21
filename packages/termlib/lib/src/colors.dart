import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;

import '../color_util.dart';
import 'shared/string_extension.dart';

/// Color kind
enum ColorKind {
  /// No color
  noColor,

  /// ANSI color (0-15)
  ansi,

  /// Indexed color (0-255)
  indexed,

  /// RGB color
  rgb
}

const _foreground = 38;
const _background = 48;
const _resetFg = 39;
const _resetBg = 49;
const _reset = -1;

// Keeps a cache for the colors requested/converted by the user to save time.
// Over time this cache must be short, because the there are no many colors
// that a terminal program will use
Map<(ColorKind, Color), Color> _colorCache = {};

/// Color class
@immutable
class Color {
  /// Color value
  final int value;

  /// Kind of Color
  final ColorKind kind;

  /// Creates a new color object. By default, it uses ANSI color
  const Color._(this.value, {this.kind = ColorKind.ansi});

  /// Resets the foreground or background color
  static const Color reset = Color._(_reset);

  /// ANSI Color: Black.
  static const Color black = Color._(0);

  /// ANSI Color: Red.
  static const Color red = Color._(1);

  /// ANSI Color: Green.
  static const Color green = Color._(2);

  /// ANSI Color: Yellow.
  static const Color yellow = Color._(3);

  /// ANSI Color: Blue.
  static const Color blue = Color._(4);

  /// ANSI Color: Magenta.
  static const Color magenta = Color._(5);

  /// ANSI Color: Cyan.
  static const Color cyan = Color._(6);

  /// ANSI Color: White.
  ///
  /// Note that this is sometimes called `silver` or `white` but we use `white` for bright white
  static const Color gray = Color._(7);

  /// ANSI Color: Bright Black.
  ///
  /// Note that this is sometimes called `light black` or `bright black` but we use `dark gray`
  static const Color darkGray = Color._(8);

  /// ANSI Color: Bright Red.
  static const Color brightRed = Color._(9);

  /// ANSI Color: Bright Green.
  static const Color brightGreen = Color._(10);

  /// ANSI Color: Bright Yellow.
  static const Color brightYellow = Color._(11);

  /// ANSI Color: Bright Blue.
  static const Color brightBlue = Color._(12);

  /// ANSI Color: Bright Magenta.
  static const Color brightMagenta = Color._(13);

  /// ANSI Color: Bright Cyan.
  static const Color brightCyan = Color._(14);

  /// ANSI Color: Bright White.
  /// Sometimes called `bright white` or `light white` in some terminals
  static const Color white = Color._(15);

  /// Represent a color with no color
  static const Color noColor = Color._(0, kind: ColorKind.noColor);

  /// Returns the hex value of the color
  String get hex => '#${value.toRadixString(16).padLeft(6, '0')}';

  /// Returns the ANSI sequence for color
  String sequence({bool background = false}) {
    switch (kind) {
      case ColorKind.ansi:
        if (value == _reset) {
          return '${background ? _resetBg : _resetFg}';
        }
        if (value < 8) {
          return '${background ? value + 10 + 30 : value + 30}';
        }
        return '${background ? value + 90 + 10 - 8 : value + 90 - 8}';
      case ColorKind.indexed:
        return '${background ? _background : _foreground};5;$value';
      case ColorKind.rgb:
        return '${background ? _background : _foreground};2;${(value >> 16) & 0xff};${(value >> 8) & 0xff};${value & 0xff}';
      case ColorKind.noColor:
        return '';
    }
  }

  /// Creates a color from an ANSI value (0-15)
  factory Color.ansi(int value) {
    if (value < 0 || value > 15) throw ArgumentError.value(value, 'value', 'must be between 0 and 15');
    return Color._(value & 0xf);
  }

  /// Creates a color from an indexed value (0-255)
  factory Color.indexed(int value) {
    if (value < 0 || value > 255) throw ArgumentError.value(value, 'value', 'must be between 0 and 255');
    return Color._(value & 0xff, kind: ColorKind.indexed);
  }

  /// Creates a color from an RGB value (0x000000-0xFFFFFF)
  factory Color.fromRGB(int rgb) {
    return Color._(rgb & 0xFFFFFF, kind: ColorKind.rgb);
  }

  /// Creates a color from a RGB components (0-255)
  factory Color.fromRGBComponent(int r, int g, int b) {
    return Color._((r << 16) | (g << 8) | b, kind: ColorKind.rgb);
  }

  /// Creates a new Color from a string.
  ///
  /// The string can be in the following formats:
  /// - #RGB or RGB
  /// - #RRGGBB or RRGGBB
  /// - x11 color name
  /// if the String is empty, will return a NoColor
  factory Color.fromString(String value) {
    if (value.isEmpty) return Color.noColor;

    Color convertFromString(String color) {
      final tmp = int.tryParse(color, radix: 16);
      if (tmp == null) throw ArgumentError.value(color, 'color', 'Invalid color format');

      if (color.length == 3) {
        final r = color.substring(0, 1).parseHex();
        final g = color.substring(1, 2).parseHex();
        final b = color.substring(2, 3).parseHex();
        return Color.fromRGBComponent(r << 4 | r, g << 4 | g, b << 4 | b);
      }
      if (color.length == 6) {
        final r = color.substring(0, 2).parseHex();
        final g = color.substring(2, 4).parseHex();
        final b = color.substring(4, 6).parseHex();
        return Color.fromRGBComponent(r, g, b);
      }
      throw ArgumentError.value(color, 'color', 'Invalid color format');
    }

    if (value.startsWith('#')) return convertFromString(value.substring(1));

    final x11 = ansi.x11Colors[value];
    if (x11 != null) return Color.fromRGB(x11);

    return convertFromString(value);
  }

  /// Convert a color to another format
  Color convert(ColorKind newKind) {
    if (kind == newKind) return this;
    if (kind == ColorKind.noColor) return this;
    if (newKind == ColorKind.noColor) return Color.noColor;
    if (kind == ColorKind.ansi) return this;

    // final cache = _colorCache[(newKind, this)];
    // if (cache != null) return cache;

    if (kind == ColorKind.indexed) {
      if (newKind == ColorKind.ansi) {
        final rc = indexedToAnsiColor();
        // _colorCache[(newKind, rc)] = rc;
        return rc;
      }
      if (newKind == ColorKind.rgb) {
        // _colorCache[(newKind, this)] = this;
        return this;
      }
    }

    if (kind == ColorKind.rgb) {
      if (newKind == ColorKind.ansi) {
        final rc = rgbToAnsiColor();
        // _colorCache[(newKind, rc)] = rc;
        return rc;
      }
      if (newKind == ColorKind.indexed) {
        final rc = rgbToIndexedColor();
        // _colorCache[(newKind, rc)] = rc;
        return rc;
      }
    }

    return this;
  }

  /// Convert an indexed color to Ansi Color
  Color indexedToAnsiColor() {
    // grayscale range
    if (value > 231) {
      if (value < 237) return Color.black;
      if (value < 250) return Color.gray;
      return Color.white;
    }

    final rgb = Color.fromRGB(ansi.ansiHex[value]);
    return rgb.rgbToAnsiColor();
  }

  /// Convert RGB to Ansi Color
  Color rgbToAnsiColor() {
    if (kind != ColorKind.rgb) throw ArgumentError.value(value, 'value', 'must be an RGB color');

    // Use a threshold-based approach instead of simple division
    final cmp = toRgbComponents();
    final r = cmp.r > 90 ? 1 : 0;
    final g = cmp.g > 90 ? 1 : 0;
    final b = cmp.b > 90 ? 1 : 0;
    final lum = colorLuminance(this);

    final ansi16 = (b << 2) | (g << 1) | r;
    if (lum >= 0.20) return Color.ansi(ansi16 + 8);
    return Color.ansi(ansi16);
  }

  /// Convert RGB to Ansi256 Color
  Color rgbToIndexedColor() {
    if (kind != ColorKind.rgb) throw ArgumentError.value(value, 'value', 'must be an RGB color');
    final rgb = toRgbComponents();

    if (rgb.r >> 4 == rgb.g >> 4 && rgb.g >> 4 == rgb.b >> 4) {
      if (rgb.r < 8) {
        return Color.indexed(16);
      }

      if (rgb.r > 248) {
        return Color.indexed(231);
      }

      return Color.indexed((((rgb.r - 8) / 247) * 24).round() + 232);
    }

    final xr = 36 * (rgb.r / 255 * 5).round();
    final xg = 6 * (rgb.g / 255 * 5).round();
    final xb = (rgb.b / 255 * 5).round();
    final ansi = 16 + xr + xg + xb;

    return Color.indexed(ansi);
  }

  /// Returns a record with RGB components
  ({int r, int b, int g}) toRgbComponents() {
    if (kind != ColorKind.rgb) throw ArgumentError.value(value, 'value', 'must be an RGB color');
    return (r: (value >> 16) & 0xFF, g: (value >> 8) & 0xFF, b: value & 0xFF);
  }

  /// Converts HSV (Hue, Saturation, Value) color values to RGB Color object.
  ///
  /// Parameters:
  /// - [hue]: The hue value in degrees. Will be normalized between 0 and 360.
  /// - [saturation]: The saturation value, clamped between 0.0 and 1.0.
  /// - [value]: The value/brightness, clamped between 0.0 and 1.0.
  ///
  /// Returns a [Color] object representing the RGB color.
  ///
  /// Note: This is specifically for HSV color space, not HSL. The main difference is
  /// that HSV's value parameter determines brightness (0 = black, 1 = full color),
  /// while HSL's lightness parameter determines lightness (0 = black, 0.5 = full color, 1 = white).
  ///
  /// Example:
  /// ```dart
  /// final color = fromHSV(0, 1.0, 1.0); // Creates pure red
  /// final color = fromHSV(0, 0.0, 1.0); // Creates white
  /// final color = fromHSV(0, 0.0, 0.0); // Creates black
  /// ```
  factory Color.fromHSV(double hue, double saturation, double value) {
    // Converts a color component value to an RGB integer value (0-255).
    int toRGB(double value) => (value * 255).round().clamp(0, 255);

    // Normalize and clamp input values
    final h = hue % 360;
    final s = saturation.clamp(0.0, 1.0);
    final v = value.clamp(0.0, 1.0);

    // Optimization: Early return for black (value = 0)
    if (v <= 0.0) {
      return Color.fromRGB(0);
    }

    // Optimization: Early return for grayscale (saturation = 0)
    if (s <= 0.0) {
      final gray = toRGB(v);
      return Color.fromRGB((gray << 16) | (gray << 8) | gray);
    }

    final hSection = h / 60.0;
    final hSectionInt = hSection.toInt();
    final f = hSection - hSectionInt;

    final p = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));

    return switch (hSectionInt) {
      0 => Color.fromRGB((toRGB(v) << 16) | (toRGB(t) << 8) | toRGB(p)),
      1 => Color.fromRGB((toRGB(q) << 16) | (toRGB(v) << 8) | toRGB(p)),
      2 => Color.fromRGB((toRGB(p) << 16) | (toRGB(v) << 8) | toRGB(t)),
      3 => Color.fromRGB((toRGB(p) << 16) | (toRGB(q) << 8) | toRGB(v)),
      4 => Color.fromRGB((toRGB(t) << 16) | (toRGB(p) << 8) | toRGB(v)),
      _ => Color.fromRGB((toRGB(v) << 16) | (toRGB(p) << 8) | toRGB(q)),
    };
  }

  @override
  String toString() {
    if (value < 0) return 'Color(Reset)';
    return 'Color($value, ${kind.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Color) {
      return value == other.value && kind == other.kind;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Color, value, kind);
}
