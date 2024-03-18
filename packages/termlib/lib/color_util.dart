/// Color utility functions
library;

import 'dart:math' as math;

import 'src/colors.dart';

/// Type of the function returned by [colorLerp] function.
/// the parameter [t] is a value between 0.0 and 1.0.
typedef LerpFunction = TrueColor Function(double t);

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
LerpFunction colorLerp(TrueColor color1, TrueColor color2) {
  TrueColor lerp(double t) {
    final value = t.clamp(0.0, 1.0);
    final r = (color1.r + (color2.r - color1.r) * value).round();
    final g = (color1.g + (color2.g - color1.g) * value).round();
    final b = (color1.b + (color2.b - color1.b) * value).round();

    return TrueColor(r, g, b);
  }

  return lerp;
}

/// Function that calculates the TrueColor luminance and returns
/// a value between 0.0 and 1.0. Being 0.0 black and 1.0 white.
double colorLuminance(TrueColor color) {
  final rsRGB = color.r / 255.0;
  final gsRGB = color.g / 255.0;
  final bsRGB = color.b / 255.0;

  final r = (rsRGB <= 0.03928) ? rsRGB / 12.92 : math.pow((rsRGB + 0.055) / 1.055, 2.4);
  final g = (gsRGB <= 0.03928) ? gsRGB / 12.92 : math.pow((gsRGB + 0.055) / 1.055, 2.4);
  final b = (bsRGB <= 0.03928) ? bsRGB / 12.92 : math.pow((bsRGB + 0.055) / 1.055, 2.4);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
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
HSV rgbToHsv(TrueColor color) {
  final r = color.r / 255;
  final g = color.g / 255;
  final b = color.b / 255;
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
