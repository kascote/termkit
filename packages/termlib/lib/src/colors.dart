import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;

import './shared/color_util.dart';
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
  rgb,
}

const _foreground = 38;
const _background = 48;
const _resetFg = 39;
const _resetBg = 49;
const _reset = -1;

// ANSI SGR color code bases
const _fgBase = 30; // standard foreground: 30-37
const _bgOffset = 10; // background = foreground + 10
const _brightBase = 90; // bright foreground: 90-97

// Keeps a cache for the colors requested/converted by the user to save time.
// Over time this cache must be short, because the there are not many colors
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

  /// Returns the ANSI sequence for color
  String sequence({bool background = false}) {
    switch (kind) {
      case ColorKind.ansi:
        if (value == _reset) {
          return '${background ? _resetBg : _resetFg}';
        }
        if (value < 8) {
          return '${background ? value + _fgBase + _bgOffset : value + _fgBase}';
        }
        return '${background ? value + _brightBase + _bgOffset - 8 : value + _brightBase - 8}';
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

  /// Creates a color from RGB components (0-255)
  factory Color.fromRGBComponent(int r, int g, int b) {
    return Color._((r << 16) | (g << 8) | b, kind: ColorKind.rgb);
  }

  /// Creates a color from an integer, auto-detecting the color kind.
  ///
  /// - 0-15: ANSI color
  /// - 16-255: indexed color
  /// - 256+: RGB color
  factory Color.fromInt(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value', 'must be non-negative');
    if (value < 16) return Color.ansi(value);
    if (value < 256) return Color.indexed(value);
    return Color.fromRGB(value);
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
      throw FormatException('Invalid color format', color);
    }

    if (value.startsWith('#')) return convertFromString(value.substring(1));

    final x11 = ansi.x11Colors[value];
    if (x11 != null) return Color.fromRGB(x11);

    return convertFromString(value);
  }

  /// Convert a color to another format.
  ///
  /// Only downgrades colors (rgb→indexed→ansi), never upgrades.
  /// This matches terminal capability semantics: use highest fidelity
  /// the terminal supports, downgrade otherwise.
  /// Results are cached for performance.
  Color convert(ColorKind newKind) {
    if (kind == newKind) return this;
    if (kind == ColorKind.noColor) return this;
    if (newKind == ColorKind.noColor) return Color.noColor;

    if (newKind.index > kind.index) return this;

    final cacheKey = (newKind, this);
    final cached = _colorCache[cacheKey];
    if (cached != null) return cached;

    final result = switch ((kind, newKind)) {
      (ColorKind.indexed, ColorKind.ansi) => indexedToAnsiColor(),
      (ColorKind.rgb, ColorKind.ansi) => rgbToAnsiColor(),
      (ColorKind.rgb, ColorKind.indexed) => rgbToIndexedColor(),
      _ => this, // unreachable
    };

    _colorCache[cacheKey] = result;
    return result;
  }

  /// Convert an indexed color to Ansi Color
  Color indexedToAnsiColor() {
    if (kind != ColorKind.indexed) throw ArgumentError.value(toString(), 'color', 'must be an indexed color');
    // gray scale range
    if (value > 231) {
      if (value < 237) return Color.black;
      if (value < 250) return Color.gray;
      return Color.white;
    }

    final rgb = Color.fromRGB(ansi.ansiHex[value]);
    return rgb.rgbToAnsiColor();
  }

  /// Convert RGB to Ansi Color using nearest-neighbor search
  Color rgbToAnsiColor() {
    if (kind != ColorKind.rgb) throw ArgumentError.value(toString(), 'color', 'must be an RGB color');
    final rgb = toRgbComponents();
    return Color.ansi(findClosestAnsi16(rgb.r, rgb.g, rgb.b));
  }

  /// Convert RGB to Ansi256 Color
  ///
  /// ANSI 256 color palette structure:
  /// - 0-15: standard ANSI colors (handled elsewhere)
  /// - 16-231: 6x6x6 color cube (216 colors)
  /// - 232-255: grayscale ramp (24 shades)
  Color rgbToIndexedColor() {
    if (kind != ColorKind.rgb) throw ArgumentError.value(toString(), 'color', 'must be an RGB color');
    final rgb = toRgbComponents();

    // Grayscale detection: R, G, B within 16 of each other (same upper nibble)
    if (rgb.r >> 4 == rgb.g >> 4 && rgb.g >> 4 == rgb.b >> 4) {
      // Near black → first color cube entry (black)
      if (rgb.r < 8) return Color.indexed(16);
      // Near white → last color cube entry (white)
      if (rgb.r > 248) return Color.indexed(231);
      // Map to grayscale ramp: 232-255 (24 shades from dark to light)
      return Color.indexed((((rgb.r - 8) / 247) * 24).round() + 232);
    }

    // Map to 6x6x6 color cube (indices 16-231)
    // Each channel maps 0-255 → 0-5, then: index = 16 + 36*r + 6*g + b
    final xr = 36 * (rgb.r / 255 * 5).round();
    final xg = 6 * (rgb.g / 255 * 5).round();
    final xb = (rgb.b / 255 * 5).round();

    return Color.indexed(16 + xr + xg + xb);
  }

  /// Returns a record with RGB components
  ({int r, int g, int b}) toRgbComponents() {
    if (kind != ColorKind.rgb) throw ArgumentError.value(toString(), 'color', 'must be an RGB color');
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
  /// final color = Color.fromHSV(0, 1.0, 1.0); // Creates pure red
  /// final color = Color.fromHSV(0, 0.0, 1.0); // Creates white
  /// final color = Color.fromHSV(0, 0.0, 0.0); // Creates black
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

    // Optimization: Early return for gray scale (saturation = 0)
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
