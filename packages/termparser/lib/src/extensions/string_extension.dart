/// Little extensions to String
extension StringExtension on String {
  /// parse the string to an int assuming is a hexadecimal representation.
  int parseHex() {
    return int.parse(trim(), radix: 16);
  }

  /// parse the string to an int assuming is a hexadecimal representation.
  int? tryParseHex() {
    return int.tryParse(trim(), radix: 16);
  }

  /// parse the string to an int assuming is a decimal representation.
  /// if it fails, it returns the default value
  int parseInt({int def = 0}) {
    return int.tryParse(this) ?? def;
  }

  /// parse a int to a character and return null if it fails
  static String? tryFromCharCode(int charCode) {
    try {
      return String.fromCharCode(charCode);
    } on Object catch (_) {
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
}
