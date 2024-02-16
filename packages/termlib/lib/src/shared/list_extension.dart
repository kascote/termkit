import './int_extension.dart';

/// Extensions for the [List<int>] class.
extension ListIntUtils on List<int> {
  /// Returns true if this list starts with the given [other] list.
  bool startsWith(List<int> other) {
    if (other.length > length) return false;
    for (var i = 0; i < other.length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }

  /// Returns true if this list ends with the given [other] list.
  bool endsWith(List<int> other) {
    if (other.length > length) return false;
    for (var i = 0; i < other.length; i++) {
      if (this[length - other.length + i] != other[i]) return false;
    }
    return true;
  }

  /// Returns a string representation of this list.
  String toStringAsRunes() => String.fromCharCodes(this, 1);

  /// Returns the elements in a string
  String toHexString() => fold(StringBuffer(), (sb, e) => sb..write('${e.toHexString()}:')).toString();
}
