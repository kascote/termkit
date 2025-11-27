import 'dart:math' as math;

import 'package:termansi/termansi.dart' as ansi;

import '../../termlib.dart';
import './string_extension.dart';

/// Find the closest ANSI 16 color index for a given RGB color.
/// Uses redmean distance with saturation penalty to avoid mapping
/// saturated colors to grays.
int findClosestAnsi16(int red, int green, int blue) {
  var minDistance = double.infinity;
  var closestIndex = 0;

  final srcChroma = _chroma(red, green, blue);

  for (var i = 0; i < 16; i++) {
    final (:r, :g, :b) = Color.fromRGB(ansi.ansiHex[i]).toRgbComponents();
    var distance = _redmeanDistanceSquared(red, green, blue, r, g, b);

    // Penalize grays when source has significant chroma
    final ansiChroma = _chroma(r, g, b);
    if (srcChroma > 40 && ansiChroma < 20) {
      distance *= 3.5; // Strong penalty for mapping chromatic to gray
    }

    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }

  return closestIndex;
}

/// Returns chroma (max - min of RGB channels) as a saturation measure.
int _chroma(int r, int g, int b) {
  final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
  return maxC - minC;
}

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

final _oscColorRx = RegExp(r'rgb:(\w{1,4})\/(\w{1,4})\/(\w{1,4})');

/// Returns a [Color] from an OSC color sequence.
///
/// the OSC response sequence is like "rgb:1111/1111/1111"
/// and must be convert to a TrueColor class.
Color? oscColor(String color) {
  final match = _oscColorRx.firstMatch(color);
  if (match == null) return null;

  final r = match.group(1)!.padLeft(2, '0').substring(0, 2).parseHex();
  final g = match.group(2)!.padLeft(2, '0').substring(0, 2).parseHex();
  final b = match.group(3)!.padLeft(2, '0').substring(0, 2).parseHex();
  return Color.fromRGBComponent(r, g, b);
}

/// Redmean squared distance - perceptual color matching.
/// Returns squared distance (no sqrt) for efficient comparisons.
/// ref: https://en.wikipedia.org/wiki/Color_difference
double _redmeanDistanceSquared(int r1, int g1, int b1, int r2, int g2, int b2) {
  final redMean = (r1 + r2) / 2.0;
  final redWeight = 2 + redMean / 256;
  final blueWeight = 2 + (255 - redMean) / 256;

  final dr = r1 - r2;
  final dg = g1 - g2;
  final db = b1 - b2;

  // return redWeight * dr * dr + 4 * dg * dg + blueWeight * db * db;

  final distance = math.sqrt(redWeight * dr * dr + 4 * dg * dg + blueWeight * db * db);
  return distance / _maxRedmeanDistance;
}

// Maximum possible distance in RGB color space using Redmean approximation.
const double _maxRedmeanDistance = 764.8339663572415; // Precomputed for efficiency

/// Returns the distance between two TrueColors utilizing the
/// "red mean" formula.
///
/// The return value is between 0 and 1. 0 means the colors are identical.
/// ref: https://en.wikipedia.org/wiki/Color_difference
double calculateRedMeanDistance(Color color1, Color color2) {
  if (color1.kind != ColorKind.rgb) throw ArgumentError.value(color1, 'color1', 'must be an RGB color');
  if (color2.kind != ColorKind.rgb) throw ArgumentError.value(color2, 'color2', 'must be an RGB color');

  final c1 = color1.toRgbComponents();
  final c2 = color2.toRgbComponents();

  return _redmeanDistanceSquared(c1.r, c1.g, c1.b, c2.r, c2.g, c2.b);
  // final distance = math.sqrt(_redmeanDistanceSquared(c1.r, c1.g, c1.b, c2.r, c2.g, c2.b));
  // return distance / _maxRedmeanDistance;
}

/// Type of the function returned by [colorLerp] function.
/// the parameter [t] is a value between 0.0 and 1.0.
typedef LerpFunction = Color Function(double t);

/// Returns a function that interpolates between two colors.
///
/// The returned function accepts a parameter between 0 and 1,
/// being 0 the first color and 1 the second color.
///
/// ex:
/// ```dart
///   final lerp = colorLerp(TrueColor(255, 0, 0), TrueColor(0, 255, 0));
///   final color = lerp(0.5); // color is TrueColor(127, 127, 0)
/// ```
LerpFunction colorLerp(Color color1, Color color2) {
  Color lerp(double t) {
    final c1 = color1.toRgbComponents();
    final c2 = color2.toRgbComponents();
    final value = t.clamp(0.0, 1.0);
    final r = (c1.r + (c2.r - c1.r) * value).round();
    final g = (c1.g + (c2.g - c1.g) * value).round();
    final b = (c1.b + (c2.b - c1.b) * value).round();

    return Color.fromRGBComponent(r, g, b);
  }

  return lerp;
}

/// Function that calculates the TrueColor luminance and returns
/// a value between 0.0 and 1.0. Being 0.0 black and 1.0 white.
double colorLuminance(Color color) {
  if (color.kind != ColorKind.rgb) throw ArgumentError.value(color.toString(), 'color', 'must be an RGB color');
  final rgb = color.toRgbComponents();
  final rsRGB = rgb.r / 255.0;
  final gsRGB = rgb.g / 255.0;
  final bsRGB = rgb.b / 255.0;

  final xr = (rsRGB <= 0.03928) ? rsRGB / 12.92 : math.pow((rsRGB + 0.055) / 1.055, 2.4);
  final xg = (gsRGB <= 0.03928) ? gsRGB / 12.92 : math.pow((gsRGB + 0.055) / 1.055, 2.4);
  final xb = (bsRGB <= 0.03928) ? bsRGB / 12.92 : math.pow((bsRGB + 0.055) / 1.055, 2.4);

  return 0.2126 * xr + 0.7152 * xg + 0.0722 * xb;
}

/// HSV color definition
typedef HSV = ({
  double h,
  double s,
  double v,
});

/// Convert a TrueColor color to HSV
//
// borrow from https://github.com/Qix-/color-convert/blob/master/conversions.js#L97
HSV rgbToHsv(Color color) {
  if (color.kind != ColorKind.rgb) throw ArgumentError.value(color.toString(), 'color', 'must be an RGB color');
  final rgb = color.toRgbComponents();

  final r = rgb.r / 255;
  final g = rgb.g / 255;
  final b = rgb.b / 255;
  final v = math.max(r, math.max(g, b));
  final diff = v - math.min(r, math.min(g, b));
  double diffc(double c) {
    return (v - c) / 6 / diff + 1 / 2;
  }

  var h = 0.0;
  var s = 0.0;

  if (diff != 0) {
    s = diff / v;
    final rdif = diffc(r);
    final gdif = diffc(g);
    final bdif = diffc(b);

    if (r == v) {
      h = bdif - gdif;
    } else if (g == v) {
      h = (1 / 3) + rdif - bdif;
    } else if (b == v) {
      h = (2 / 3) + gdif - rdif;
    }

    if (h < 0) {
      h += 1;
    } else if (h > 1) {
      h -= 1;
    }
  }

  return (h: h * 360, s: s * 100, v: v * 100);
}

/// Return a terminal profile based on the color kind
ProfileEnum termProfileFromColorKind(ColorKind kind) => switch (kind) {
  ColorKind.noColor => ProfileEnum.noColor,
  ColorKind.ansi => ProfileEnum.ansi16,
  ColorKind.indexed => ProfileEnum.ansi256,
  ColorKind.rgb => ProfileEnum.trueColor,
};

/// Return a ColorKind based on the terminal profile
ColorKind colorKindFromProfile(ProfileEnum profile) => switch (profile) {
  ProfileEnum.noColor => ColorKind.noColor,
  ProfileEnum.ansi16 => ColorKind.ansi,
  ProfileEnum.ansi256 => ColorKind.indexed,
  ProfileEnum.trueColor => ColorKind.rgb,
};
