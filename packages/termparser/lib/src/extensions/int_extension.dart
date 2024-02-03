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
}

///
extension ListIntUtils on List<int> {
  /// Returns the elements in a string
  String toHexString() => fold(StringBuffer(), (sb, e) => sb..write('${e.toRadixString(16)}:')).toString();
}
