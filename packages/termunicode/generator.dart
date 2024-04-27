import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import './lib/term_ucd.dart';

const _baseUrl = 'https://www.unicode.org/Public/';
const _version = '15.1.0';

const _maxCodePoints = 0x10FFFF;
const _nonPrintableCategories = ['Cc', 'Cf', 'Zl', 'Zp', 'Cs', 'Cn', 'Co', 'C'];
const _zeroCharacterWidth = ['Cc', 'Mn', 'Me'];
const _blockSize = 256;
const _destinationDirectory = './data';
const _destinationFile = './lib/src/table.dart';
const _tabChars = '  ';

Future<void> main() async {
  final tables = Tables();
  await tables.generate();
  tables.emitTables();
}

///
class Tables {
  /// EastAsianWidth UCD file
  late final EastAsianWidthUCD eaw;

  /// UnicodeData UCD file
  late final UnicodeDataUCD uniData;

  /// EmojiData UCD file
  late final EmojiDataUCD emoji;

  /// DerivedCodeProps UCD file
  late final DerivedCodePropsUCD dcp;

  /// HangulSyllableType UCD file
  late final HangulSyllableTypeUCD hst;

  final _tables = <String, List<int>>{
    'stage1': [],
    'stage2': [],
    'stage3': [],
  };

  /// Download UCD files and generate the lookup tables
  Future<void> generate() async {
    await downloadFiles(saveTo: _destinationDirectory);

    eaw = EastAsianWidthUCD(path.join(_destinationDirectory, EastAsianWidthUCD.fileName));
    uniData = UnicodeDataUCD(path.join(_destinationDirectory, UnicodeDataUCD.fileName));
    emoji = EmojiDataUCD(path.join(_destinationDirectory, EmojiDataUCD.fileName));
    dcp = DerivedCodePropsUCD(path.join(_destinationDirectory, DerivedCodePropsUCD.fileName));
    hst = HangulSyllableTypeUCD(path.join(_destinationDirectory, HangulSyllableTypeUCD.fileName));

    await eaw.parse();
    await uniData.parse();
    await emoji.parse();
    await dcp.parse();
    await hst.parse();

    final block = <int>[];
    final blockLut = <String, int>{};

    for (var cp = 0; cp <= _maxCodePoints; cp++) {
      final cpData = getCPData(cp);

      var stage3Idx = _tables['stage3']!.indexOf(cpData);
      if (stage3Idx == -1) {
        _tables['stage3']!.add(cpData);
        stage3Idx = _tables['stage3']!.length - 1;
      }

      block.add(stage3Idx);

      if (block.length == _blockSize || cp == _maxCodePoints) {
        final hash = hashArray(block);
        var startIdx = blockLut[hash];

        if (startIdx == null) {
          startIdx = _tables['stage2']!.length;
          _tables['stage2']!.addAll(block);
          blockLut[hash] = startIdx;
        }

        _tables['stage1']!.add(startIdx);
        block.clear();
      }
    }
  }

  /// Get the data for a code point.
  int getCPData(int cp) {
    var isEmoji = false;
    var nonPrintable = false;
    final charWidth = getCharWidth(cp);

    final data = uniData.find(cp);
    if (data != null && _nonPrintableCategories.contains(data.category)) nonPrintable = true;

    // Emoji UCD has definitions for some lower codepoints, they are excluded
    if (cp >= 0x40) {
      final emo = emoji.find(cp);
      if (emo != null) {
        // Regional Indicator Symbols are not considered emojis for the purpose of
        // determining character width. They are used to compose country flags.
        if (emo.start < 0x1f1e6 || emo.end > 0x1f1ff) {
          isEmoji = true;
          // // only take care for Emoji_Presentation, if not use EAW
          // if (emo.property == 'Emoji_Presentation') charWidth = 2;
        }
      }
    }

    /*

   char width ----------------------+--+
   emoji      -------------------+  |  |
   non printable -------------+  |  |  |
   non char      ----------+  |  |  |  |
   private       -------+  |  |  |  |  |
                        |  |  |  |  |  |
   */
    final bits = [0, 0, 0, 0, 0, 0, 0, 0];

    if (data != null && data.category == 'Co') bits[2] = 1;
    if (data != null && data.category == 'non-character') bits[3] = 1;
    if (data != null && nonPrintable) bits[4] = 1;
    if (isEmoji) bits[5] = 1;
    bits[6] = charWidth & 0x2 == 0x2 ? 1 : 0;
    bits[7] = charWidth & 0x1 == 0x1 ? 1 : 0;

    return bits.fold(0, (acc, bit) => (acc << 1) | bit);
  }

  /// Determine char width for a code point.
  int getCharWidth(int cp) {
    var charWidth = 0;

    final eawChar = eaw.find(cp);
    charWidth = switch (eawChar.property) {
      'N' || 'H' || 'Na' => 1, // N: Neutral, H: HalfWidth, Na: Narrow
      'W' || 'F' => 2, // W: Wide, F: FullWidth
      'A' => 3, // A: Ambiguous
      _ => throw Exception('Unknown East Asian Width: ${eawChar.property}'),
    };

    final data = uniData.find(cp);
    if (data != null) {
      if (_zeroCharacterWidth.contains(data.category)) charWidth = 0;
    }

    // `Default_Ignorable_Code_Point`s also have 0 width:
    // https://www.unicode.org/faq/unsup_char.html#3
    // https://www.unicode.org/versions/Unicode15.1.0/ch05.pdf#G40095
    // taken from unicode-rs https://github.com/unicode-rs
    if (dcp.findProp('Default_Ignorable_Code_Point', cp) != null) charWidth = 0;

    // Treat `Hangul_Syllable_Type`s of `Vowel_Jamo` and `Trailing_Jamo`
    // as zero-width. This matches the behavior of glibc `wcwidth`.
    //
    // Decomposed Hangul characters consist of 3 parts: a `Leading_Jamo`,
    // a `Vowel_Jamo`, and an optional `Trailing_Jamo`. Together these combine
    // into a single wide grapheme. So we treat vowel and trailing jamo as
    // 0-width, such that only the width of the leading jamo is counted
    // and the resulting grapheme has width 2.
    //
    // (See the Unicode Standard sections 3.12 and 18.6 for more on Hangul)
    // taken from unicode-rs https://github.com/unicode-rs
    final hstChar = hst.find(cp);
    if (['V', 'T'].contains(hstChar.property)) charWidth = 0;

    // Special case: U+115F HANGUL CHOSEONG FILLER.
    // U+115F is a `Default_Ignorable_Code_Point`, and therefore would normally have
    // zero width. However, the expected usage is to combine it with vowel or trailing jamo
    // (which are considered 0-width on their own) to form a composed Hangul syllable with
    // width 2. Therefore, we treat it as having width 2.
    // taken from unicode-rs https://github.com/unicode-rs
    if (cp == 0x115f) charWidth = 2;

    // The soft hyphen (`U+00AD`) is single-width. (https://archive.is/fCT3c)
    // taken from unicode-rs https://github.com/unicode-rs
    if (cp == 0x00ad) charWidth = 1;

    return charWidth;
  }

  /// Emit the final file with the tables.
  void emitTables() {
    final out = File(_destinationFile).openWrite()
      ..writeln('// ignore_for_file: public_member_api_docs')
      ..writeln("import 'dart:typed_data';\n")
      ..writeln('// AUTO GENERATED FILE - DO NOT EDIT\n')
      ..writeln("const unicodeUCD = '$_version';\n");

    _emitStage('stage1', 'Uint16List', out, 11);
    _emitStage('stage2', 'Uint8List', out, 19);
    _emitStage('stage3', 'Uint8List', out, 19);

    out.close();
  }

  void _emitStage(String stage, String container, IOSink file, int chunkSize) {
    file.writeln('final $stage = $container.fromList([');

    final stageLength = _tables[stage]!.length;
    for (var i = 0; i < stageLength; i++) {
      if (i == 0) file.write(_tabChars);
      if (i > 0 && i % chunkSize == 0) file.write('\n$_tabChars');
      file.write('0x${_tables[stage]![i].toRadixString(16)},');
    }

    file.writeln('\n]);');
  }
}

/// Generate a hash from a list of integers.
String hashArray(List<int> integers) {
  final byteData = Uint8List.fromList(integers.expand((i) => [i >> 24, i >> 16, i >> 8, i & 0xFF]).toList());
  final hash = sha256.convert(byteData);
  return hash.toString();
}

/// Get Files
Future<void> downloadFiles({required String saveTo}) async {
  final files = [
    (path: '$_baseUrl$_version/ucd/', filename: EastAsianWidthUCD.fileName),
    (path: '$_baseUrl$_version/ucd/', filename: UnicodeDataUCD.fileName),
    (path: '$_baseUrl$_version/ucd/emoji/', filename: EmojiDataUCD.fileName),
    (path: '$_baseUrl$_version/ucd/', filename: DerivedCodePropsUCD.fileName),
    (path: '$_baseUrl$_version/ucd/', filename: HangulSyllableTypeUCD.fileName),
  ];

  for (final file in files) {
    await downloadFile('${file.path}${file.filename}', saveTo, file.filename);
  }
}

/// Create a directory if it doesn't exist.
void createDirectoryIfNotExists(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

/// Get a file from a URL.
Future<http.Response> getFileFromUrl(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response;
  } else {
    throw Exception('Failed to download file. Status code: ${response.statusCode}');
  }
}

/// Save a byte array to a file.
void saveFile(String filePath, List<int> bytes) {
  File(filePath).writeAsBytesSync(bytes);
}

/// Download a file from a URL and save it to a file.
/// If the file already exists, it will not be downloaded again.
Future<void> downloadFile(String url, String targetPath, String filePath) async {
  try {
    final targetFile = path.join(targetPath, filePath);
    final file = File(targetFile);
    if (file.existsSync()) return;

    // Get the directory path after ensuring the file doesn't exist
    final dirPath = path.dirname(targetFile);
    stdout.writeln('Downloading $url to $targetFile');
    createDirectoryIfNotExists(dirPath);

    final response = await getFileFromUrl(url);
    final bytes = response.bodyBytes;
    saveFile(targetFile, bytes);
  } on FileSystemException catch (e) {
    stderr.writeln('Error creating directory: $e');
  } on IOException catch (e) {
    stderr.writeln('Error downloading file: $e');
  }
}
