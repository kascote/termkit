import 'dart:math' as math;

import '../../termlib.dart';
import './string_extension.dart';

/// Find the closest ANSI color index for a given RGB color.
int findClosestAnsiIndex(int red, int green, int blue) {
  // Initialize minimum distance and closest index
  var minDistance = 1 << 32;
  var closestIndex = 0;

  // Loop through all 256 ANSI colors
  for (var i = 0; i < 256; i++) {
    // Extract components based on ANSI color index formula
    final ansiRed = ((i >> 8) & 0x0F) * 17;
    final ansiGreen = (((i >> 4) & 0x0F) & 0x03) * 36 + 5;
    final ansiBlue = (i & 0x0F) * 6 + 5;

    // Calculate Euclidean distance between RGB and ANSI colors
    final distance = _calculateEuclideanDistance(red, green, blue, ansiRed, ansiGreen, ansiBlue);

    // Update minimum distance and closest index if closer color found
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }

  return closestIndex;
}

int _calculateEuclideanDistance(int rgbRed, int rgbGreen, int rgbBlue, int ansiRed, int ansiGreen, int ansiBlue) {
  // Calculate squared differences for each color component
  final redDiff = (rgbRed - ansiRed) * (rgbRed - ansiRed);
  final greenDiff = (rgbGreen - ansiGreen) * (rgbGreen - ansiGreen);
  final blueDiff = (rgbBlue - ansiBlue) * (rgbBlue - ansiBlue);

  // Calculate and return the Euclidean distance
  return math.sqrt(redDiff + greenDiff + blueDiff).round();
}

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

final _oscColorRx = RegExp(r'rgb:(\w{1,4})\/(\w{1,4})\/(\w{1,4})');

/// Returns a [Color] from an OSC color sequence.
///
/// the OSC response sequence is like "rgb:1111/1111/1111"
/// and must be convert to a TrueColor class.
Color? oscColor(String color) {
  Color? result;

  _oscColorRx.allMatches(color).forEach((match) {
    final r = match.group(1)!.padLeft(2, '0').substring(0, 2).parseHex();
    final g = match.group(2)!.padLeft(2, '0').substring(0, 2).parseHex();
    final b = match.group(3)!.padLeft(2, '0').substring(0, 2).parseHex();
    result = Color.fromRGBComponent(r, g, b);
  });

  return result;
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
  // Calculate the average of the red components.
  final redMean = (c1.r + c2.r) / 2.0;

  // Calculate the square differences for each color channel with redmean adjustment.
  final redWeight = 2 + redMean / 256;
  final blueWeight = 2 + (255 - redMean) / 256;

  final redDiff = c2.r - c1.r;
  final greenDiff = c2.g - c1.g;
  final blueDiff = c2.b - c1.b;

  final redComponent = redWeight * redDiff * redDiff;
  final greenComponent = 4 * greenDiff * greenDiff;
  final blueComponent = blueWeight * blueDiff * blueDiff;

  // Calculate the Redmean distance.
  final distance = math.sqrt(redComponent + greenComponent + blueComponent);

  // Normalize the distance to a range between 0 and 1.
  return distance / _maxRedmeanDistance;
}

/// Type of the function returned by [colorLerp] function.
/// the parameter [t] is a value between 0.0 and 1.0.
typedef LerpFunction = Color Function(double t);

/// Returns a function that interpolates between two colors.
///
/// The returned function accepts a parameter betwee 0 and 1,
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
  if (color.kind != ColorKind.rgb) throw ArgumentError.value(color.value, 'color', 'must be an RGB color');
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
  if (color.kind != ColorKind.rgb) throw ArgumentError.value(color.value, 'color', 'must be an RGB color');
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
