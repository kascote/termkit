/// Extension methods for [int].
extension IntUtils on int {
  /// Returns a string representation as hex value
  String get hex2 => toRadixString(16).padLeft(2, '0');

  /// Return the hex representation
  String toHexString({int padding = 2}) => toRadixString(16).padLeft(padding, '0');

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
