import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

Future<void> main() async {
  final term = TermLib();

  final initial = await term.queryColorScheme();
  if (initial != null) {
    term.writeln('Initial: ${initial.mode.name.toUpperCase()}\r');
  }

  term
    ..enableRawMode()
    ..enableColorPaletteUpdates()
    ..writeln('Color scheme monitor. Press any key to exit.\r')
    ..writeln('Waiting for changes...\r\n');

  while (true) {
    final event = await term.read<Event>();

    if (event is ColorSchemeEvent) {
      term.writeln('Color scheme: ${event.mode.name.toUpperCase()}\r');
    } else if (event is KeyEvent) {
      break;
    } else {
      term.writeln('Event: $event\r');
    }
  }

  term
    ..writeln('\nExiting...\r')
    ..disableColorPaletteUpdates()
    ..disableRawMode();
  await term.flushThenExit(0);
}
