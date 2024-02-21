import 'dart:async';

import 'package:termlib/src/shared/list_extension.dart';
import 'package:termlib/termlib.dart';

Future<void> main(List<String> arguments) async {
  final t = TermLib();

  if (arguments.contains('-kitty')) {
    const keyFlags = KeyboardEnhancementFlags(
      KeyboardEnhancementFlags.disambiguateEscapeCodes |
          KeyboardEnhancementFlags.reportAlternateKeys |
          KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes |
          KeyboardEnhancementFlags.reportEventTypes,
    );
    t.setCapabilities(keyFlags);
  }

  await t.withRawModeAsync(() => keyViewer(t));
  await t.flushThenExit(0);
}

Future<void> keyViewer(TermLib t) async {
  t
    ..eraseClear()
    ..enableMouseEvents()
    ..writeln(' ')
    ..writeln(' ')
    ..writeln('Press any key to see the key details.')
    ..writeln('Press ESC to exit.');

  try {
    while (true) {
      final data = await t.readRawKeys();
      if (data.isEmpty) continue;
      if (data.startsWith([0x1b, 0x5b, 0x32, 0x37, 0x3b, 0x31, 0x75])) break;
      if (data.length == 1 && data.first == 0x1b) break;

      final dataHex =
          data.fold(StringBuffer(), (sb, e) => sb..write('${e.toRadixString(16).padLeft(2, '0')} ')).toString();
      final dataStr = data
          .fold(
            StringBuffer(),
            (sb, e) => sb
              ..write('${e.isPrintable ? String.fromCharCode(e) : e == 0x1b ? 'ESC' : '.'} '),
          )
          .toString();
      t.writeln('Data: $dataHex - $dataStr');
    }
  } catch (e, st) {
    t
      ..writeln('Error: $e')
      ..writeln(st);
  } finally {
    t
      ..setCapabilities(const KeyboardEnhancementFlags(0))
      ..disableMouseEvents();
  }
}
