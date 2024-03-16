import 'dart:io';

import 'package:termlib/termlib.dart';

void main() {
  final t = TermLib();
  final s = t.style;

  t
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My Terminal Application')
    ..writeAt(
      10,
      10,
      s('Hello, World!')..setFg(Color.make('yellow')),
    );

  sleep(const Duration(seconds: 2));

  t
    ..disableAlternateScreen()
    ..cursorShow()
    ..flushThenExit(0);
}
