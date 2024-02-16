import 'int_extension.dart';

/// List extension
extension ListUtils<T> on List<T> {
  /// Returns the first element or null if the list is empty.
  T? get firstOrNull => isNotEmpty ? first : null;

  /// Returns the last element or null if the list is empty.
  T? get lastOrNull => isNotEmpty ? last : null;
}

///
extension ListIntUtils on List<int> {
  /// Returns the elements in a string
  String toHexString() => fold(StringBuffer(), (sb, e) => sb..write('${e.toHexString()}:')).toString();
}
