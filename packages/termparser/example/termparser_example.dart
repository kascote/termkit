import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

// run with
// dart run --enable-asserts example/termparser_example.dart

void main() {
  final parser = Parser()
    // ESC [ 20 ; 10 R
    ..advance([0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52]);
  assert(parser.moveNext(), 'move next');
  assert(parser.current == const CursorPositionEvent(20, 10), 'retrieve event');
  assert(parser.moveNext() == false, 'no more events');
}
