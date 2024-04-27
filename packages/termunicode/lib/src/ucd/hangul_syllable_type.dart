import 'ucd_base.dart';
import 'ucd_parser.dart';

///
class HangulSyllableTypeItem extends UcdItemBase {
  /// Property
  String property;

  /// Category
  String category;

  /// Default constructor
  HangulSyllableTypeItem(super.start, super.end, this.property, this.category);

  @override
  String toString() => '0x${start.toRadixString(16)}..0x${end.toRadixString(16)}: $property ($category)';
}

// All code points not explicitly listed for Hangul_Syllable_Type
// have the value Not_Applicable (NA).
HangulSyllableTypeItem _missingItem = HangulSyllableTypeItem(0, 0, 'NA', 'not applicable');

/// A class that provides information about the Hangul Syllable Type of a character
class HangulSyllableTypeUCD extends UcdBase<HangulSyllableTypeItem> {
  /// The filename of the UCD file
  static const fileName = 'HangulSyllableType.txt';

  /// Creates a new instance of [HangulSyllableTypeUCD] from a file
  HangulSyllableTypeUCD(super.filename);

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

      codePoints.add(HangulSyllableTypeItem(row.rangeStart, row.rangeEnd, row.fields[1], category));
    });

    await parser.parse();
    sort();
  }

  /// Returns the Hangul Syllable Type of a character
  @override
  HangulSyllableTypeItem find(int codePoint) {
    return super.find(codePoint) ?? _missingItem;
  }
}
