import 'ucd_base.dart';
import 'ucd_parser.dart';

/// Contains information about an Emoji characters range
class EmojiDataItem extends UcdItemBase {
  /// Property
  String property;

  /// Version
  double version;

  /// Default constructor
  EmojiDataItem(super.start, super.end, this.property, this.version);
}

/// A class that provides information about the East Asian Width of a character
///
/// ref: https://www.unicode.org/reports/tr11/tr11-41.html
class EmojiDataUCD extends UcdBase<EmojiDataItem> {
  /// The filename of the UCD file
  static const fileName = 'emoji-data.txt';

  /// Creates a new instance of [EmojiDataUCD] from a file
  EmojiDataUCD(super.filename);

  /// Initiates the parsing of the UCD file
  @override
  Future<void> parse() async {
    final parser = UcdParser.parseFile(filename, (row) {
      if (row.error.isNotEmpty) {
        throw UcdException(row.error);
      }

      var version = 0.0;
      if (row.comment.isNotEmpty) {
        final rx = RegExp(r'^\s*E(\d+\.\d+)');
        version = double.parse(rx.firstMatch(row.comment)?[1] ?? '0.0');
      }

      codePoints.add(
        EmojiDataItem(
          row.rangeStart,
          row.rangeEnd,
          row.getField(1),
          version,
        ),
      );
    });

    await parser.parse();
    sort();
  }
}
