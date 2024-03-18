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
}
