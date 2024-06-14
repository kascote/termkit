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

// Maximum possible distance in RGB color space using Redmean approximation.
const double _maxRedmeanDistance = 764.8339663572415; // Precomputed for efficiency

/// Returns the distance between two TrueColors utilizing the
/// "red mean" formula.
///
/// The return value is between 0 and 1. 0 means the colors are identical.
/// ref: https://en.wikipedia.org/wiki/Color_difference
double calculateRedMeanDistance(TrueColor color1, TrueColor color2) {
  // Calculate the average of the red components.
  final redMean = (color1.r + color2.r) / 2.0;

  // Calculate the square differences for each color channel with redmean adjustment.
  final redWeight = 2 + redMean / 256;
  final blueWeight = 2 + (255 - redMean) / 256;

  final redDiff = color2.r - color1.r;
  final greenDiff = color2.g - color1.g;
  final blueDiff = color2.b - color1.b;

  final redComponent = redWeight * redDiff * redDiff;
  final greenComponent = 4 * greenDiff * greenDiff;
  final blueComponent = blueWeight * blueDiff * blueDiff;

  // Calculate the Redmean distance.
  final distance = math.sqrt(redComponent + greenComponent + blueComponent);

  // Normalize the distance to a range between 0 and 1.
  return distance / _maxRedmeanDistance;
}
