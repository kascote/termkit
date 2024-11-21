import 'dart:async';
import 'dart:io';

import 'package:termlib/src/shared/list_extension.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import './shared.dart';

Future<void> main(List<String> arguments) async {
  final t = TermLib();
  final withKitty = arguments.contains('-kitty');

  if (withKitty) t.enableKeyboardEnhancement();

  ProcessSignal.sigterm.watch().listen((event) {
    t
      ..writeln('SIGTERM received')
      ..disableKeyboardEnhancement()
      ..disableMouseEvents()
      ..disableRawMode()
      ..flushThenExit(0);
  });

  await t.withRawModeAsync(() => keyViewer(t));
  await t.flushThenExit(0);
}

Future<void> keyViewer(TermLib t) async {
  t
    ..eraseClear()
    ..enableMouseEvents()
    ..writeln(' ')
    ..writeln('Press any key to see the key details.')
    ..writeln('Press ESC to exit.');

  final s = t.style;
  final cyan = s()..fg(Color.fromString('cyan'));
  final green = s()..fg(Color.fromString('green'));
  final gray = s()..fg(Color.fromString('webGray'));

  try {
    while (true) {
      final event = await t.readEvent<RawKeyEvent>(rawKeys: true);
      if (event is! RawKeyEvent) continue;
      if (event.sequence.isEmpty) continue;

      final seq = event.sequence;
      if (seq.startsWith([0x1b, 0x5b, 0x32, 0x37, 0x75])) break;
      if (seq.startsWith([0x1b, 0x5b, 0x32, 0x37, 0x3b, 0x31, 0x75])) break;
      if (seq.startsWith([0x1b, 0x5b, 0x32, 0x37, 0x3b, 0x31, 0x3b, 0x32, 0x37, 0x75])) break;
      if (seq.length == 1 && seq.first == 0x1b) break;

      final dataHex = seq.fold(StringBuffer(), (sb, e) => sb..write(cyan('${e.toRadixString(16).padLeft(2, '0')} ')));
      final dataStr = seq.fold(
        StringBuffer(),
        (sb, e) => sb
          ..write(green('${isPrintable(e) ? String.fromCharCode(e) : e == 0x1b ? 'ESC' : '.'} ')),
      );

      t.writeln('${gray('hex:')} $dataHex - ${gray('seq:')} $dataStr');
    }
  } catch (e, st) {
    t
      ..writeln('Error: $e')
      ..writeln(st);
  } finally {
    t
      ..setKeyboardFlags(const KeyboardEnhancementFlagsEvent(0))
      ..disableMouseEvents();
  }
}
