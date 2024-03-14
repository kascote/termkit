import 'dart:io';

import 'package:termlib/termlib.dart';

void main() {
  final t = TermLib();
  final p = t.profile;

  t
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My Terminal Application')
    ..writeAt(
      10,
      10,
      p.style('Hello, World!')..setFg(t.profile.getColor('yellow')),
    );

  sleep(const Duration(seconds: 2));

  t
    ..disableAlternateScreen()
    ..cursorShow()
    ..flushThenExit(0);
}
