import 'package:termansi/termansi.dart';

import './colors.dart';
import './shared/color_util.dart' show findClosestAnsiIndex;
import './style.dart';

/// Enumeration representing different profiles.
enum ProfileEnum {
  /// Represents a no color profile.
  noColor,

  /// Represents an ANSI 16 color.
  ansi16,

  /// Represents an ANSI 256 color.
  ansi256,

  /// Represents an RGB color.
  trueColor,
}

// Keeps a cache for the colors requested/converted by the user to save time.
// Over time this cache must be short, because the there are no many colors
// that a terminal program will use
Map<(ProfileEnum, String), Color> _colorCache = {};

/// A class representing a screen profile.
///
/// The Profile is used to convert colors to the current profile.
/// Is not needed to use the library, but is convenient because will simplify
/// the use of colors.
class Profile {
  late ProfileEnum _profile;

  /// Creates a new Profile. The default profile is ANSI 256.
  Profile({ProfileEnum profile = ProfileEnum.ansi256}) {
    _profile = profile;
  }

  /// Returns an Style for the current profile
  Style style([String content = '']) => Style(content, profile: _profile);

  /// Tries to parse a string into a Color object
  ///
  /// If the color string is empty,  the [defaultColor] will be used, by default
  /// defaultColor is [NoColor]
  /// If the color string starts with a '#', it is assumed to be an RGB color.
  /// If the color string is a number, it is assumed to be an ANSI 16 or 256 color,
  /// if not, will return [defaultColor]
  ///
  /// A color cache, using the profile and passed color, is used to save time.
  /// The function [clearColorCache] can be used to clear the cache.
  Color getColor(String color, {Color defaultColor = const NoColor()}) {
    if (color.isEmpty) return defaultColor;

    final cachedValue = _colorCache[(_profile, color)];
    if (cachedValue != null) return cachedValue;

    final result = _getColor(color);
    if (result == null) return defaultColor;

    _colorCache[(_profile, color)] = result;
    return result;
  }

  // resolves a color string to a Color object using different methods
  Color? _getColor(String color) {
    final mix = x11Colors[color] ?? color;
    Color c;
    if (mix.startsWith('#')) {
      c = TrueColor.fromString(mix);
    } else {
      final colNum = int.tryParse(mix);
      if (colNum == null) return null;
      c = (colNum < 16 ? Ansi16Color(colNum) : Ansi256Color(colNum)) as Color;
    }

    return convert(c);
  }

  /// Clears the color cache.
  void clearColorCache() => _colorCache.clear();

  /// Converts a color to the current profile.
  Color convert(Color srcColor) {
    if (_profile == ProfileEnum.noColor) return const NoColor();
    if (srcColor.profile == _profile) return srcColor;

    Color convertFromTrueColor(TrueColor clr) {
      if (_profile == ProfileEnum.ansi16) {
        return _convertRgbToAnsi256(clr).toAnsi16Color();
      } else if (_profile == ProfileEnum.ansi256) {
        return _convertRgbToAnsi256(clr);
      } else {
        return srcColor;
      }
    }

    Color convertToTrueColor(Color clr) {
      if (clr.profile == ProfileEnum.ansi16) {
        return TrueColor.fromString(ansiHex[(clr as Ansi16Color).code]);
      } else if (clr.profile == ProfileEnum.ansi256) {
        return TrueColor.fromString(ansiHex[(clr as Ansi256Color).code]);
      } else {
        return clr;
      }
    }

    return switch (srcColor.profile) {
      ProfileEnum.noColor => const NoColor(),
      ProfileEnum.ansi16 =>
        _profile == ProfileEnum.ansi256 ? Ansi256Color((srcColor as Ansi16Color).code) : convertToTrueColor(srcColor),
      ProfileEnum.ansi256 =>
        _profile == ProfileEnum.ansi16 ? (srcColor as Ansi256Color).toAnsi16Color() : convertToTrueColor(srcColor),
      ProfileEnum.trueColor => convertFromTrueColor(srcColor as TrueColor)
    };
  }

  /// Converts an RGB color to an ANSI 256 color.
  Ansi256Color _convertRgbToAnsi256(TrueColor color) {
    // Calculate the closest color index in the 256-color ANSI palette
    final closestIndex = findClosestAnsiIndex(color.r, color.g, color.b);
    return Ansi256Color(closestIndex);
  }
}
