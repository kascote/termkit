/// List extension
extension ListUtils<T> on List<T> {
  /// Returns the first element or null if the list is empty.
  T? get firstOrNull => isNotEmpty ? first : null;

  /// Returns the last element or null if the list is empty.
  T? get lastOrNull => isNotEmpty ? last : null;
}
