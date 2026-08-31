import 'dart:math' as math;

import 'package:termansi/termansi.dart' as ansi;

import '../../termlib.dart';
import 'string_extension.dart';

/// Find the closest ANSI 16 color index for a given RGB color.
///
/// Matches in OKLab, a perceptually uniform color space, so the search is
/// hue-aware: a desaturated color is compared by lightness and hue rather
/// than by raw channel proximity, so it is never mistaken for a
/// differently-hued palette entry just because one channel happens to be
/// numerically close.
///
/// Plain OKLab distance alone lets lightness dominate hue at the edges of
/// the palette: against only 16 candidates, a fully neutral gray can be
/// closer in lightness to a saturated color than to any of the four true
/// grays, and a fairly saturated color can likewise be closer in lightness
/// to a gray than to any chromatic entry. Both are wrong in the same way
/// (matching lightness across a category boundary that should not cross),
/// so the search first checks how far the source itself sits from neutral:
///
/// - Source OKLab chroma at or below 0.03 (essentially gray): search only
///   the four neutral candidates (black, dark gray, gray, white), so a
///   near-neutral source can only ever match a near-neutral candidate.
/// - Source OKLab chroma at or above 0.09 (clearly a color): search only
///   the twelve chromatic candidates, so a colorful source can never
///   collapse onto a gray just because a gray happens to be lighter- or
///   darker-matched.
/// - In between: search all 16 candidates by plain OKLab distance, same as
///   before -- there is no clean neutral/chromatic call to make, so let
///   lightness and hue trade off freely.
int findClosestAnsi16(int red, int green, int blue) {
  final src = _srgbToOklab(red, green, blue);
  final chroma = math.sqrt(src.a * src.a + src.b * src.b);
  final neutralOnly = chroma <= _neutralChromaCeiling;
  final chromaticOnly = chroma >= _chromaticChromaFloor;

  var minDistance = double.infinity;
  var closestIndex = 0;

  for (var i = 0; i < 16; i++) {
    if (neutralOnly && !_ansi16Neutral[i]) continue;
    if (chromaticOnly && _ansi16Neutral[i]) continue;

    final distance = _oklabDeltaSquared(src, _ansi16Oklab[i]);
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }

  return closestIndex;
}

// Source OKLab chroma at or below this is treated as neutral: only the
// four gray-family ANSI-16 candidates are searched.
const double _neutralChromaCeiling = 0.03;

// Source OKLab chroma at or above this is treated as clearly chromatic:
// only the twelve non-gray ANSI-16 candidates are searched.
const double _chromaticChromaFloor = 0.09;

// OKLab coordinates of the 16 base ANSI colors, computed once on first
// access. Dart initializes a top-level `final` lazily, which matters here:
// the conversion runs a cube root, so this list can't be `const`-folded.
final List<_Oklab> _ansi16Oklab = List.generate(16, (i) {
  final hex = ansi.ansiHex[i];
  return _srgbToOklab((hex >> 16) & 0xff, (hex >> 8) & 0xff, hex & 0xff);
}, growable: false);

// Whether each ANSI-16 palette entry is neutral (r == g == b): indices 0
// (black), 7 (silver), 8 (dark gray), 15 (white). Computed once alongside
// [_ansi16Oklab].
final List<bool> _ansi16Neutral = List.generate(16, (i) {
  final hex = ansi.ansiHex[i];
  final r = (hex >> 16) & 0xff;
  final g = (hex >> 8) & 0xff;
  final b = hex & 0xff;
  return r == g && g == b;
}, growable: false);

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// A color's coordinates in OKLab space: `l` is perceptual lightness, `a`
/// runs green-to-red and `b` runs blue-to-yellow.
typedef _Oklab = ({double l, double a, double b});

/// Linearizes one sRGB channel (0-255) to [0, 1], undoing the sRGB gamma
/// curve so the channel can be mixed linearly.
double _linearizeSrgbChannel(int channel) {
  final c = channel / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Converts an sRGB color (0-255 per channel) to OKLab.
///
/// ref: https://bottosson.github.io/posts/oklab/
_Oklab _srgbToOklab(int red, int green, int blue) {
  final r = _linearizeSrgbChannel(red);
  final g = _linearizeSrgbChannel(green);
  final b = _linearizeSrgbChannel(blue);

  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  // l, m, s are non-negative for any in-gamut sRGB input, so a plain
  // pow(x, 1/3) is a valid, real-valued cube root here.
  final lRoot = math.pow(l, 1 / 3).toDouble();
  final mRoot = math.pow(m, 1 / 3).toDouble();
  final sRoot = math.pow(s, 1 / 3).toDouble();

  return (
    l: 0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot,
    a: 1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot,
    b: 0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot,
  );
}

/// Squared Euclidean distance between two OKLab coordinates.
///
/// Left un-square-rooted: every caller only compares distances against one
/// another to find a minimum, and never needs the absolute value.
double _oklabDeltaSquared(_Oklab c1, _Oklab c2) {
  final dl = c1.l - c2.l;
  final da = c1.a - c2.a;
  final db = c1.b - c2.b;
  return dl * dl + da * da + db * db;
}

/// Squared OKLab distance between two RGB colors.
///
/// A perceptual, hue-aware alternative to [calculateRedMeanDistance] used
/// for nearest-color search. Deliberately not exported from the package
/// barrel (see `lib/color_util.dart`): it is an implementation detail
/// shared across files within the library, between this function and
/// `Color.rgbToIndexedColor`.
double oklabDistanceSquared(Color color1, Color color2) {
  if (color1.kind != ColorKind.rgb) throw ArgumentError.value(color1, 'color1', 'must be an RGB color');
  if (color2.kind != ColorKind.rgb) throw ArgumentError.value(color2, 'color2', 'must be an RGB color');

  final c1 = color1.toRgbComponents();
  final c2 = color2.toRgbComponents();
  return _oklabDeltaSquared(_srgbToOklab(c1.r, c1.g, c1.b), _srgbToOklab(c2.r, c2.g, c2.b));
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

/// Redmean distance - perceptual color matching.
/// Returns a normalized distance between 0 and 1.
/// ref: https://en.wikipedia.org/wiki/Color_difference
double _redmeanDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
  final redMean = (r1 + r2) / 2.0;
  final redWeight = 2 + redMean / 256;
  final blueWeight = 2 + (255 - redMean) / 256;

  final dr = r1 - r2;
  final dg = g1 - g2;
  final db = b1 - b2;

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

  return _redmeanDistance(c1.r, c1.g, c1.b, c2.r, c2.g, c2.b);
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
