/// Base Class to define line items in the UCD file
class UcdItemBase {
  /// Start of the range
  int start;

  /// End of the range
  int end;

  /// Default constructor
  UcdItemBase(this.start, this.end);
}

/// Base Class to define the UCD file
class UcdBase<T> {
  /// List of codePoints definitions
  List<T> codePoints = [];

  /// UCD file name
  String filename;

  /// Creates a new instance of [UcdBase] from a file
  UcdBase(this.filename);

  /// Initiates the parsing of the UCD file.
  /// This method should be implemented in the child class
  Future<void> parse() async {
    throw UnimplementedError('parse() method not implemented');
  }

  /// Finds a codePoint or return a default item as 'N" (Neutral) category
  T? find(int target) {
    return findIn(codePoints, target);

    // var left = 0;
    // var right = codePoints.length - 1;
    //
    // while (left <= right) {
    //   final middle = (left + right) ~/ 2;
    //   final middleRange = codePoints[middle] as UcdItemBase;
    //
    //   if (target < middleRange.start) {
    //     right = middle - 1;
    //   } else if (target > middleRange.end) {
    //     left = middle + 1;
    //   } else {
    //     return codePoints[middle];
    //   }
    // }
    //
    // return null;
  }

  /// Sort the codepoints
  void sort() {
    codePoints.sort((a, b) => (a as UcdItemBase).start.compareTo((b as UcdItemBase).start));
  }

  /// Find codepoint in an abritrary list of items
  T? findIn(List<T> items, int target) {
    var left = 0;
    var right = items.length - 1;

    while (left <= right) {
      final middle = (left + right) ~/ 2;
      final middleRange = items[middle] as UcdItemBase;

      if (target < middleRange.start) {
        right = middle - 1;
      } else if (target > middleRange.end) {
        left = middle + 1;
      } else {
        return items[middle];
      }
    }

    return null;
  }
}
