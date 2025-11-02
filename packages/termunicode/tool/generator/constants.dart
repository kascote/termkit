const String baseUrl = 'https://www.unicode.org/Public/';
const String version = '15.1.0';

const int maxCodePoints = 0x10FFFF;
const List<String> nonPrintableCategories = ['Cc', 'Cf', 'Zl', 'Zp', 'Cs', 'Cn', 'Co', 'C'];
const List<String> zeroCharacterWidth = ['Cc', 'Mn', 'Me'];
const int blockSize = 256;
const String destinationDirectory = './data';
const String destinationFile = './lib/src/table.dart';
const String tabChars = '  ';
