/// Extension on the `String` class to provide additional functionality.
extension StringExtension on String {
  /// Converts the string to a hexadecimal representation.
  String dumpHex({bool onlyHex = false}) {
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      final char = this[i];
      final code = char.codeUnitAt(0);
      final hex = '0x${code.toRadixString(16).padLeft(2, '0')}';
      if (onlyHex) {
        sb.write('$hex:');
      } else {
        sb.write(code >= 32 && code <= 126 ? char : hex);
      }
    }
    return sb.toString();
  }

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
    if (codePoint >= 0x30 && codePoint <= 0x39) return false;
    return this == toUpperCase();
  }
}
