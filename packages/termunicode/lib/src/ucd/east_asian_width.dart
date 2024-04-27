import 'ucd_base.dart';
import 'ucd_parser.dart';

/// Contains information about an East Asian Width characters range
class EastAsianWidthItem extends UcdItemBase {
  /// Property
  String property;

  /// Category
  String category;

  /// Default constructor
  EastAsianWidthItem(super.start, super.end, this.property, this.category);

  @override
  String toString() => '0x${start.toRadixString(16)}..0x${end.toRadixString(16)}: $property ($category)';
}

// Default item for missing code points.
// from the ucd file:
//   - All code points, assigned or unassigned, that are not listed
//     explicitly are given the value "N".
EastAsianWidthItem _missingItem = EastAsianWidthItem(0, 0, 'N', 'missing');

/// default property for missing East Asian Width or in CJK ideographs range
const exceptionEAWProperty = 'CJK ideograph';

/// A class that provides information about the East Asian Width of a character
///
/// ref: https://www.unicode.org/reports/tr11/tr11-41.html
class EastAsianWidthUCD extends UcdBase<EastAsianWidthItem> {
  /// The filename of the UCD file
  static const fileName = 'EastAsianWidth.txt';

  //  - The unassigned code points in the following blocks default to "W":
  //         CJK Unified Ideographs Extension A: U+3400..U+4DBF
  //         CJK Unified Ideographs:             U+4E00..U+9FFF
  //         CJK Compatibility Ideographs:       U+F900..U+FAFF
  //  - All undesignated code points in Planes 2 and 3, whether inside or
  //      outside of allocated blocks, default to "W":
  //         Plane 2:                            U+20000..U+2FFFD
  //         Plane 3:                            U+30000..U+3FFFD
  final List<({int start, int end})> _specialCases = [
    (start: 0x3400, end: 0x4DBF),
    (start: 0x4E00, end: 0x9FFF),
    (start: 0xF900, end: 0xFAFF),
    (start: 0x20000, end: 0x2FFFD),
    (start: 0x30000, end: 0x3FFFD),
  ];

  /// Creates a new instance of [EastAsianWidthUCD] from a file
  EastAsianWidthUCD(super.filename);

  /// Initiates the parsing of the UCD file
  @override
  Future<void> parse() async {
    final parser = UcdParser.parseFile(filename, (row) {
      if (row.error.isNotEmpty) {
        throw UcdException(row.error);
      }

      var category = '';
      if (row.comment.isNotEmpty && row.comment.length > 3) {
        category = row.comment.substring(0, 2).trim();
      }

      codePoints.add(
        EastAsianWidthItem(
          row.rangeStart,
          row.rangeEnd,
          row.getField(1),
          category,
        ),
      );
    });

    await parser.parse();
    sort();
  }

  /// Finds a codePoint or return a default item as 'N" (Neutral) category
  @override
  EastAsianWidthItem find(int target) {
    final char = super.find(target);
    if (char != null) return char;

    for (final special in _specialCases) {
      if (target >= special.start && target <= special.end) {
        return EastAsianWidthItem(special.start, special.end, 'W', exceptionEAWProperty);
      }
    }

    return _missingItem;
  }
}
