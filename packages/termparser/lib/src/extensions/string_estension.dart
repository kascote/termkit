import './int_extension.dart';

/// Little extensions to String
extension StringExtension on String {
  /// parse the string to an int assuming is a hexadecimal representation.
  int parseHex() {
    return int.parse(trim(), radix: 16);
  }

  /// Try to parse the string to an int assuming is a hexadecimal representation.
  static String? tryFromCharCode(int charCode) {
    try {
      return String.fromCharCode(charCode);
    } catch (e) {
      return null;
    }
  }

  /// Returns `true` if the string is uppercase.
  bool isUpperCase() {
    if (length == 0) return false;
    final codePoint = codeUnitAt(0);
    // 0 through 9 returns true for toUpperCase
    if (codePoint >= 0x30 && codePoint <= 0x39) return true;
    return this == toUpperCase();
  }

  /// Converts the string to a hexadecimal representation.
  String dumpHex({bool onlyHex = false}) {
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      final char = this[i];
      final code = char.codeUnitAt(0);
      final hex = '0x${code.toHexString()}';
      final value = onlyHex
          ? hex
          : code.isPrintable
              ? char
              : hex;
      sb.write(value);
    }
    return sb.toString();
  }
}
