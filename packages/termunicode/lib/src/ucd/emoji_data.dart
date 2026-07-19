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

/// A class that provides information about the emoji properties of a character
///
/// ref: https://www.unicode.org/reports/tr51/
class EmojiDataUCD extends UcdBase<EmojiDataItem> {
  /// The filename of the UCD file
  static const fileName = 'emoji-data.txt';

  /// Creates a new instance of [EmojiDataUCD] from a file
  EmojiDataUCD(super.filename);

  // One codepoint can carry several properties, so ranges in the flat
  // [codePoints] list overlap; only the per-property lists are disjoint
  // and safe to binary-search.
  final _properties = <String, List<EmojiDataItem>>{};

  /// Property names present in the file, in first-appearance order.
  Iterable<String> get properties => _properties.keys;

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

      final item = EmojiDataItem(
        row.rangeStart,
        row.rangeEnd,
        row.getField(1),
        version,
      );
      codePoints.add(item);
      (_properties[item.property] ??= []).add(item);
    });

    await parser.parse();
    sort();
    for (final items in _properties.values) {
      items.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  /// Finds the range carrying [property] that covers [target], or null.
  EmojiDataItem? findProp(String property, int target) {
    final items = _properties[property];
    if (items == null) return null;

    return findIn(items, target);
  }

  /// Finds a range covering [target], or null if no property covers it.
  ///
  /// Searches property by property in file order and returns the first
  /// covering range. Use [findProp] when a specific property is meant.
  @override
  EmojiDataItem? find(int target) {
    for (final items in _properties.values) {
      final item = findIn(items, target);
      if (item != null) return item;
    }
    return null;
  }
}
