// ignore_for_file: avoid_print, document_ignores
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

Future<void> main() async {
  final term = TermLib();

  final initial = await term.queryColorScheme();
  if (initial != null) {
    print('Initial: ${initial.mode.name.toUpperCase()}\r');
  }

  term
    ..enableRawMode()
    ..enableColorPaletteUpdates();

  print('Color scheme monitor. Press any key to exit.\r');
  print('Waiting for changes...\r\n');

  while (true) {
    final event = await term.read<Event>();

    if (event is ColorSchemeEvent) {
      print('Color scheme: ${event.mode.name.toUpperCase()}\r');
    } else if (event is KeyEvent) {
      break;
    } else {
      print('Event: $event\r');
    }
  }

  print('\nExiting...\r');
  term
    ..disableColorPaletteUpdates()
    ..disableRawMode();
  await term.flushThenExit(0);
}
