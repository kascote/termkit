/// Traverse the list by the given path.
/// ex: listTraverse<int>([1, 2, [3, 4]], '2.1') => 4
T? listTraverse<T>(Object list, String path) {
  if (path.isEmpty) return null;
  var result = list;

  for (final part in path.split('.')) {
    if (result is! List) return null;
    final idx = int.tryParse(part);
    if (idx == null || idx < 0 || result.length <= idx) return null;
    result = result[idx] as Object;
  }

  if (result is T) return result as T;
  return null;
}
