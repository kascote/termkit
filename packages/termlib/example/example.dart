import 'dart:io';

import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = TermLib();
  final color = await t.isBackgroundDark() ? Color('yellow') : Color('blue');

  t
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My Terminal Application')
    ..writeAt(5, 5, t.style('Hello, World!')..fg(color));

  sleep(const Duration(seconds: 2));

  t
    ..disableAlternateScreen()
    ..cursorShow();
  await t.flushThenExit(0);
}
