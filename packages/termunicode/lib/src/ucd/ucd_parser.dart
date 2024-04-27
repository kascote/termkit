import 'dart:convert';
import 'dart:io';

// valid UCD boolean values.
final _booleans = <String, bool>{
  '': false,
  'N': false,
  'No': false,
  'F': false,
  'False': false,
  'Y': true,
  'Yes': true,
  'T': true,
  'True': true,
};

/// Represents a row in the Unicode Character Database (UCD).
class UcdRow {
  /// If there is an error parsing the line, this field will have an error message
  String error = '';

  /// The comment for this row if present
  String comment = '';

  /// All the fields in the row split by the semicolon
  List<String> fields = [];

  /// The line number in the UCD file, starting from 1 and counting all lines
  /// including comments and empty lines.
  int line = 0;

  /// The start of the range
  int rangeStart = -1;

  /// The end of the range. If the range is a single value, this will be the same as [rangeStart]
  int rangeEnd = -1;

  /// Whether to keep the ranges. This is used as a flag when reading range values that extends
  /// multiple lines.
  bool keepRanges = false;

  /// Returns the field at index [i] if it exists, otherwise returns an empty string.
  String getField(int i) {
    if (i < 0 || i >= fields.length) return '';
    return fields[i];
  }

  /// Returns the boolean value of the field at index [i]. If the field is not a valid boolean value
  /// will return false.
  bool getBool(int i) {
    final field = getField(i);
    final value = _booleans[field];
    if (value == null) error = 'invalid boolean value: $field';
    return value ?? false;
  }

  /// Returns the string value of the field at index [i].
  String getString(int i) => getField(i);

  /// Returns the unsigned integer value of the field at index [i]. If the field is not a valid unsigned
  /// integer value will return -1.
  int getUint(int i) {
    final field = getField(i);
    final value = int.tryParse(field);
    if (value == null || value < 0) {
      error = 'invalid unsigned integer value: $field';
      return -1;
    }
    return value;
  }

  /// Returns the integer value of the field at index [i]. If the field is not a valid integer value
  /// will return -1.
  int getInt(int i) {
    final field = getField(i);
    final value = int.tryParse(field);
    if (value == null) {
      error = 'invalid integer value: $field';
      return -1;
    }
    return value;
  }

  /// Returns the float value of the field at index [i]. If the field is not a valid float value
  /// will return -1.
  double getFloat(int i) {
    final field = getField(i);
    final value = double.tryParse(field);
    if (value == null) {
      error = 'invalid float value: $field';
      return -1;
    }
    return value;
  }

  /// Returns the rune value of the field at index [index]. If the field is not a valid rune value
  /// will return -1.
  int getRune(int index) => _parseRune(getField(index));

  /// Returns a list of rune values from the field at index [index]
  List<int> getRunes(int index) {
    final value = getField(index);
    if (value.isEmpty) return [];
    return value.split(' ').map(_parseRune).toList();
  }

  /// Parses the range values from the field at index [index].
  /// When the range is multiline and is reading the first value, [rangeEnd] will be -1
  /// and [keepRanges] will be true.
  void getRange(int index) {
    final f = getField(index);

    if (f.contains('..')) {
      final parts = f.split('..');
      rangeStart = _parseRune(parts[0]);
      rangeEnd = _parseRune(parts[1]);
      return;
    }

    final ini = _parseRune(f);

    if (index == 0 && fields.length > 1 && fields[1].contains('First>')) {
      rangeStart = ini;
      rangeEnd = -1;
      keepRanges = true;
      return;
    }

    if (index == 0 && fields.length > 1 && fields[1].contains('Last>')) {
      rangeEnd = ini;
      keepRanges = false;
      return;
    }

    rangeStart = rangeEnd = ini;
  }

  int _parseRune(String value) {
    var tmp = value;
    if (value.length > 2 && value[0] == 'U' && value[1] == '+') {
      tmp = value.substring(2);
    }
    final intValue = int.tryParse(tmp, radix: 16);
    if (intValue == null) {
      error = 'failed to parse rune: $value';
      return -1;
    }
    return intValue;
  }
}

/// Exception thrown when there is an error parsing the UCD file.
final class UcdException implements Exception {
  /// Exception message
  final String message;

  /// Creates a new UcdException with the provided message.
  const UcdException(this.message);
}

const _commentChar = '#';
const _atChar = '@';

/// Callback definition used to handle Comments in the UCD file.
typedef CommentHandler = void Function(String comment);

/// Callback definition used to handle Parts in the UCD file.
typedef PartHandler = void Function(UcdRow row);

/// Callback definition used to handle Data in the UCD file.
typedef DataHandler = void Function(UcdRow row);

/// Parser to read the Unicode Character Database (UCD) files.
/// The parser will read the UCD file line by line and call the appropriate callback when
/// a Comment, Part or Data is found.
///
/// ref: https://www.unicode.org/reports/tr44/
class UcdParser {
  /// Callback to handle Data in the UCD file.
  final DataHandler onData;

  /// Callback to handle Comments in the UCD file.
  CommentHandler? onComment;

  /// Callback to handle Parts in the UCD file.
  PartHandler? onPart;
  final UcdRow _row = UcdRow();
  Stream<String>? _ucdStream;

  /// Creates a new UCD Parser with the provided [onData] callback.
  /// Optionally, you can provide callbacks for Comments and Parts.
  UcdParser(
    this.onData, {
    this.onComment,
    this.onPart,
  });

  /// Creates a new UCD Parser from a file with the provided [onData] callback.
  /// Optionally, you can provide callbacks for Comments and Parts.
  factory UcdParser.parseFile(
    String filePath,
    DataHandler onData, {
    CommentHandler? onComment,
    PartHandler? onPart,
  }) {
    return UcdParser(onData, onComment: onComment, onPart: onPart)
      .._ucdStream = File(filePath).openRead().transform(utf8.decoder).transform(const LineSplitter());
  }

  /// Creates a new UCD Parser from a stream with the provided [onData] callback.
  /// Optionally, you can provide callbacks for Comments and Parts.
  factory UcdParser.parseStream(
    Stream<String> fileStream,
    DataHandler onData, {
    CommentHandler? onComment,
    PartHandler? onPart,
  }) {
    return UcdParser(onData, onComment: onComment, onPart: onPart).._ucdStream = fileStream;
  }

  /// Parses the UCD file line by line and calls the appropriate callback when a Comment, Part or Data is found.
  Future<void> parse() async {
    if (_ucdStream == null) {
      throw const UcdException('No stream provided');
    }

    await for (var line in _ucdStream!) {
      _row.line++;
      line = line.trim();
      if (line.isEmpty) continue;

      _row
        ..fields.clear()
        ..comment = '';

      if (line[0] == _commentChar) {
        if (onComment != null) onComment?.call(line.substring(1).trim());
        continue;
      }

      if (line.indexOf(_commentChar) > 0) {
        final parts = line.split(_commentChar);
        line = parts[0].trim();
        _row.comment = parts[1].trim();
      }

      if (line[0] == _atChar) {
        if (onPart != null) {
          _row.fields.add(line.substring(1).trim());
          onPart?.call(_row);
        }
        _row.comment = '';
        continue;
      }

      line.split(';').forEach((part) => _row.fields.add(part.trim()));

      _row.getRange(0);
      if (!_row.keepRanges) onData(_row);
    }
  }
}
