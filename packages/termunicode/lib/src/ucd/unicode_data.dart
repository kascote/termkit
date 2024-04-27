import 'ucd_base.dart';
import 'ucd_parser.dart';

/// Contains information about an Unicode Data characters range
class UnicodeDataItem extends UcdItemBase {
  /// Name
  String name;

  /// https://www.unicode.org/reports/tr44/#General_Category_Values
  String category;

  /// https://www.unicode.org/reports/tr44/#Canonical_Combining_Class_Values
  String canonicalCombiningClass;

  /// https://www.unicode.org/reports/tr44/#Bidi_Class_Values
  String bidiClass;

  /// https://www.unicode.org/reports/tr44/#Character_Decomposition_Mappings
  String decomposition;

  ///
  String decimalDigitValue;

  ///
  String digitValue;

  ///
  String numericValue;

  ///
  String mirrored;

  ///
  String unicode1Name;

  ///
  String isoComment;

  ///
  String simpleUppercaseMapping;

  ///
  String simpleLowercaseMapping;

  ///
  String simpleTitlecaseMapping;

  /// Default constructor
  UnicodeDataItem(
    super.start,
    super.end, {
    required this.name,
    required this.category,
    required this.canonicalCombiningClass,
    required this.bidiClass,
    required this.decomposition,
    required this.decimalDigitValue,
    required this.digitValue,
    required this.numericValue,
    required this.mirrored,
    required this.unicode1Name,
    required this.isoComment,
    required this.simpleUppercaseMapping,
    required this.simpleLowercaseMapping,
    required this.simpleTitlecaseMapping,
  });

  @override
  String toString() => '0x${start.toRadixString(16)}..0x${end.toRadixString(16)}: $name ($category)';
}

/// default non-character name
const defaultNonCharacter = 'Non Character';

/// default non-character category
const defaultCategory = 'non-character';

/// UnicodeData.txt parser
class UnicodeDataUCD extends UcdBase<UnicodeDataItem> {
  /// The filename of the UCD file
  static const fileName = 'UnicodeData.txt';
  // https://www.unicode.org/faq/private_use.html#noncharacters
  final List<({int start, int end})> _nonCharacters = [
    (start: 0xFDD0, end: 0xFDEF),
    (start: 0xFFFE, end: 0xFFFF),
    (start: 0x1FFFE, end: 0x1FFFF),
    (start: 0x2FFFE, end: 0x2FFFF),
    (start: 0x3FFFE, end: 0x3FFFF),
    (start: 0x4FFFE, end: 0x4FFFF),
    (start: 0x5FFFE, end: 0x5FFFF),
    (start: 0x6FFFE, end: 0x6FFFF),
    (start: 0x7FFFE, end: 0x7FFFF),
    (start: 0x8FFFE, end: 0x8FFFF),
    (start: 0x9FFFE, end: 0x9FFFF),
    (start: 0xAFFFE, end: 0xAFFFF),
    (start: 0xBFFFE, end: 0xBFFFF),
    (start: 0xCFFFE, end: 0xCFFFF),
    (start: 0xDFFFE, end: 0xDFFFF),
    (start: 0xEFFFE, end: 0xEFFFF),
    (start: 0xFFFFE, end: 0xFFFFF),
    (start: 0x10FFFE, end: 0x10FFFF),
  ];

  /// Creates a new instance of [UnicodeDataUCD] from a file
  UnicodeDataUCD(super.filename);

  /// Initiates the parsing of the UCD file
  @override
  Future<void> parse() async {
    final parser = UcdParser.parseFile(filename, (row) {
      if (row.error.isNotEmpty) {
        throw UcdException(row.error);
      }

      codePoints.add(
        UnicodeDataItem(
          row.rangeStart,
          row.rangeEnd,
          name: row.getField(1),
          category: row.getField(2),
          canonicalCombiningClass: row.getField(3),
          bidiClass: row.getField(4),
          decomposition: row.getField(5),
          decimalDigitValue: row.getField(6),
          digitValue: row.getField(7),
          numericValue: row.getField(8),
          mirrored: row.getField(9),
          unicode1Name: row.getField(10),
          isoComment: row.getField(11),
          simpleUppercaseMapping: row.getField(12),
          simpleLowercaseMapping: row.getField(13),
          simpleTitlecaseMapping: row.getField(14),
        ),
      );
    });

    await parser.parse();
    sort();
  }

  /// Finds a codePoint or return null if not found
  @override
  UnicodeDataItem? find(int target) {
    final char = super.find(target);
    if (char != null) return char;

    if (_isNonCharacter(target)) {
      return UnicodeDataItem(
        target,
        target,
        name: defaultNonCharacter,
        category: defaultCategory,
        canonicalCombiningClass: '',
        bidiClass: '',
        decomposition: '',
        decimalDigitValue: '',
        digitValue: '',
        numericValue: '',
        mirrored: '',
        unicode1Name: '',
        isoComment: '',
        simpleUppercaseMapping: '',
        simpleLowercaseMapping: '',
        simpleTitlecaseMapping: '',
      );
    }

    return null;
  }

  bool _isNonCharacter(int codePoint) {
    for (final range in _nonCharacters) {
      if (codePoint >= range.start && codePoint <= range.end) {
        return true;
      }
    }
    return false;
  }
}
