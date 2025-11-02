import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:termunicode/term_ucd.dart';

import 'constants.dart';

/// Get Files
Future<void> downloadFiles({required String saveTo}) async {
  final files = [
    (path: '$baseUrl$version/ucd/', filename: EastAsianWidthUCD.fileName),
    (path: '$baseUrl$version/ucd/', filename: UnicodeDataUCD.fileName),
    (path: '$baseUrl$version/ucd/emoji/', filename: EmojiDataUCD.fileName),
    (path: '$baseUrl$version/ucd/', filename: DerivedCodePropsUCD.fileName),
    (path: '$baseUrl$version/ucd/', filename: HangulSyllableTypeUCD.fileName),
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
  final targetFile = path.join(targetPath, filePath);
  final file = File(targetFile);
  if (file.existsSync()) return;

  final dirPath = path.dirname(targetFile);
  stdout.writeln('Downloading $url to $targetFile');
  createDirectoryIfNotExists(dirPath);

  final response = await getFileFromUrl(url);
  final bytes = response.bodyBytes;
  saveFile(targetFile, bytes);
}
