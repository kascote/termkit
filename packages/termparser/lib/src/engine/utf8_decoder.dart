import 'dart:convert';

const _maxUtf8CodePoints = 4;

/// Helper class to decode UTF-8 sequences
class Utf8Decoder {
  final _utf8Points = List<int>.filled(_maxUtf8CodePoints, 0);
  int _utf8PointsCount = 0;
  int _utf8PointsExpectedCount = 0;

  /// Creates a new Utf8Decoder
  Utf8Decoder() {
    _utf8Points.fillRange(0, _utf8Points.length, 0);
  }

  /// Add byte to UTF-8 sequence
  void addByte(int byte) {
    _utf8Points[_utf8PointsCount] = byte;
    _utf8PointsCount++;
  }

  /// Check if UTF-8 sequence is complete
  bool isComplete() => _utf8PointsCount == _utf8PointsExpectedCount;

  /// Get decoded codepoint
  String getCodePoint() {
    return utf8.decode(_utf8Points.sublist(0, _utf8PointsCount));
  }

  /// Reset decoder
  void reset() {
    _utf8PointsCount = 0;
    _utf8PointsExpectedCount = 0;
  }

  void _startsByteSequence(int expectedCount, int firstByte) {
    _utf8PointsCount = 1;
    _utf8Points[0] = firstByte;
    _utf8PointsExpectedCount = expectedCount;
  }

  /// Start 2-byte UTF-8 sequence
  void start2Byte(int firstByte) => _startsByteSequence(2, firstByte);

  /// Start 3-byte UTF-8 sequence
  void start3Byte(int firstByte) => _startsByteSequence(3, firstByte);

  /// Start 4-byte UTF-8 sequence
  void start4Byte(int firstByte) => _startsByteSequence(4, firstByte);
}
