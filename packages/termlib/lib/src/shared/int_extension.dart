/// Extension methods for [int].
extension IntUtils on int {
  /// Returns `true` if this is a printable character.
  ///
  /// quick check for printable characters. for more advanced check review
  /// https://github.com/xxgreg/dart_printable_char
  bool get isPrintable {
    // Fast check for Latin-1
    if (this <= 0xFF) {
      if (0x20 <= this && this <= 0x7E) {
        // All the ASCII is printable from space through DEL-1.
        return true;
      }
      if (0xA1 <= this && this <= 0xFF) {
        // Similarly for ¡ through ÿ...
        return this != 0xAD; // ...except for the bizarre soft hyphen.
      }
    }
    return false;
  }

  /// Returns a string representation as hex value
  String get hex2 => toRadixString(16).padLeft(2, '0');

  /// Returns a string character representation if this is a printable character.
  String get printable => isPrintable ? String.fromCharCode(this) : '.';

  /// Subtracts [other] from this integer, returning the result.
  ///
  /// If the result is less than the minimum value of [int], the minimum value is returned.
  /// If the result is greater than the maximum value of [int], the maximum value is returned.
  int saturatingSub(int other) {
    if (this < other) return 0;
    return this - other;
  }

  /// Checks if the given [mask] is set in the integer value.
  bool isSet(int mask) => (this & mask) == mask;

  /// Checks if the given [mask] is not set in the integer value.
  bool isNotSet(int mask) => (this & mask) == 0;
}
