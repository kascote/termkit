import 'dart:io';

import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = Term.open() as InteractiveTerm;
  final isDark = await t.isBackgroundDark();
  final color = (isDark ?? false) ? Color.yellow : Color.blue;

  t
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My Terminal Application')
    ..writeAt(5, 5, t.style(fg: color)('Hello, World!'));

  sleep(const Duration(seconds: 2));

  t
    ..disableAlternateScreen()
    ..cursorShow();

  await t.dispose();
  await t.flushThenExit(0);
}
