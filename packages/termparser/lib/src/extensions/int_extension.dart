const _maxInt = 0x7FFFFFFF;

/// Extension on [int] to add some utility methods
extension IntUtils on int {
  /// Returns the result of multiplying this [int] with [value] and saturating the result
  // this is not bulletproof, but it's good enough for our use case
  int saturatingMul(int value) {
    final result = this * value;
    return result > _maxInt ? _maxInt : result;
  }

  /// Returns the result of adding this [int] with [value] and saturating the result
  int saturatingAdd(int value) {
    final result = this + value;
    return result > _maxInt ? _maxInt : result;
  }

  /// Return the hex representation
  String toHexString() => toRadixString(16);

  /// Check if a bit is set
  bool isSet(int mask) => (this & mask) == mask;

  /// Subtracts [other] from this integer, returning the result.
  ///
  /// If the result is less than the minimum value of [int], the minimum value is returned.
  /// If the result is greater than the maximum value of [int], the maximum value is returned.
  int saturatingSub(int other) {
    if (this < other) return 0;
    return this - other;
  }
}

///
extension ListIntUtils on List<int> {
  /// Returns the elements in a string
  String toHexString() => fold(StringBuffer(), (sb, e) => sb..write('${e.toRadixString(16)}:')).toString();
}
