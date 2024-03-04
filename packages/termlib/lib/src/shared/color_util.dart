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
