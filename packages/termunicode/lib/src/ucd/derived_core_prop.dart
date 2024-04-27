import 'ucd_base.dart';
import 'ucd_parser.dart';

/// Contains information about Derived Code Properties
class DeriveCodePropsItem extends UcdItemBase {
  /// Property
  String property;

  /// Category
  String category;

  /// Break
  String breaker;

  /// Default constructor
  DeriveCodePropsItem(super.start, super.end, this.property, this.category, this.breaker);

  @override
  String toString() => '0x${start.toRadixString(16)}..0x${end.toRadixString(16)}: $property ($category) $breaker';
}

// Derived Properties
final _derivedProps = <String, List<DeriveCodePropsItem>>{};

/// A class that provides information about the Derived Code Properties of a character
class DerivedCodePropsUCD extends UcdBase<DeriveCodePropsItem> {
  /// The filename of the UCD file
  static const fileName = 'DerivedCoreProperties.txt';

  /// Creates a new instance of [DerivedCodePropsUCD] from a file
  DerivedCodePropsUCD(super.filename);

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

      final prop = row.getField(1);
      final props = _derivedProps[prop] ?? <DeriveCodePropsItem>[]
        ..add(
          DeriveCodePropsItem(
            row.rangeStart,
            row.rangeEnd,
            row.getField(1),
            category,
            row.getField(2),
          ),
        );
      _derivedProps[prop] = props;
    });

    await parser.parse();

    _derivedProps.forEach(
      (k, v) => v.sort((a, b) => (a as UcdItemBase).start.compareTo((b as UcdItemBase).start)),
    );
  }

  /// Finds a codePoint or return null if not found
  DeriveCodePropsItem? findProp(String property, int target) {
    final props = _derivedProps[property];
    if (props == null) return null;

    return findIn(props, target);
  }
}
