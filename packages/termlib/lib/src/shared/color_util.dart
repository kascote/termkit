import 'dart:math' as math;

import 'package:termlib/src/shared/string_extension.dart';

import '../colors.dart';

/// Find the closest ANSI color index for a given RGB color.
int findClosestAnsiIndex(int red, int green, int blue) {
  // Initialize minimum distance and closest index
  var minDistance = 1 << 32;
  var closestIndex = 0;

  // Loop through all 256 ANSI colors
  for (var i = 0; i < 256; i++) {
    final ansiRed = _getAnsiRed(i);
    final ansiGreen = _getAnsiGreen(i);
    final ansiBlue = _getAnsiBlue(i);

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

int _getAnsiRed(int index) {
  // Extract red component based on ANSI color index formula
  final redIndex = (index >> 8) & 0x0F;
  return redIndex * 17;
}

int _getAnsiGreen(int index) {
  // Extract green component based on ANSI color index formula
  final greenIndex = ((index >> 4) & 0x0F) & 0x03;
  return greenIndex * 36 + 5;
}

int _getAnsiBlue(int index) {
  // Extract blue component based on ANSI color index formula
  final blueIndex = index & 0x0F;
  return blueIndex * 6 + 5;
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

/// Returns a [TrueColor] from an OSC color sequence.
///
/// the OSC response sequence is like "rgb:1111/1111/1111"
/// and must be convert to a TrueColor class.
TrueColor? oscColor(String color) {
  TrueColor? result;

  _oscColorRx.allMatches(color).forEach((match) {
    final r = match.group(1)!.padLeft(2, '0').substring(0, 2).parseHex();
    final g = match.group(2)!.padLeft(2, '0').substring(0, 2).parseHex();
    final b = match.group(3)!.padLeft(2, '0').substring(0, 2).parseHex();
    result = TrueColor(r, g, b);
  });

  return result;
}

/// Type of the function returned by [colorLerp] function.
/// the parameter [t] is a value between 0.0 and 1.0.
typedef LerpFunction = TrueColor Function(double t);

/// Returns a function that interpolates between two colors.
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

/// Returns the distance between two TrueColors utilizing the
/// "red mean" formula.
///
/// The return value is between 0 and 1. 0 means the colors are identical.
/// ref: https://en.wikipedia.org/wiki/Color_difference
double calculateRedMeanDistance(TrueColor color1, TrueColor color2) {
  final r1 = _linearize(color1.r);
  final g1 = _linearize(color1.g);
  final b1 = _linearize(color1.b);

  final r2 = _linearize(color2.r);
  final g2 = _linearize(color2.g);
  final b2 = _linearize(color2.b);

  // Calculate squared differences
  final rDiff = (r1 - r2) * (r1 - r2);
  final gDiff = (g1 - g2) * (g1 - g2);
  final bDiff = (b1 - b2) * (b1 - b2);

  final distance = math.sqrt(((0.299 * rDiff) + (0.587 * gDiff) + (0.114 * bDiff)) / 3);

  return distance;
}

// Helper function for linearization
double _linearize(int colorComponent) {
  const a = 0.055;
  if (colorComponent <= 0.03928) {
    return colorComponent / 12.92;
  } else {
    return math.pow((colorComponent + a) / (1 + a), 2.4) * 1.0;
  }
}
