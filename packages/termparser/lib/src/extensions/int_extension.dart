const _maxInt = 0x7FFFFFFF;

/// Extension on [int] to add some utility methods
extension IntUtils on int {
  /// Returns the result of multiplying this [int] with [value]
  /// If the value is greater than maximum int32 then maximum int32 is returned (0x7FFFFFFF)
  // this is not bulletproof, but it's good enough for our use case
  int saturatingMul(int value) {
    final result = this * value;
    return result > _maxInt ? _maxInt : result;
  }

  /// Returns the result of adding this [int] with [value]
  /// If the value is greater than maximum int32 then maximum int32 is returned (0x7FFFFFFF)
  // this is not bulletproof, but it's good enough for our use case
  int saturatingAdd(int value) {
    final result = this + value;
    return result > _maxInt ? _maxInt : result;
  }

  /// Subtracts [other] from this integer, returning the result.
  /// If the result is less than 0, 0 is returned
  int saturatingSub(int other) {
    if (this < other) return 0;
    return this - other;
  }

  /// Return the hex representation
  String toHexString({int padding = 2}) => toRadixString(16).padLeft(padding, '0');

  /// Check if a bit mask is set
  bool isSet(int mask) => (this & mask) == mask;

  /// Returns `true` if this is a printable character.
  // quick check for printable characters. for more advanced check review
  // https://github.com/xxgreg/dart_printable_char
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
}
