import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

Future<void> main() async {
  final term = TermLib();

  final status = await term.queryInBandResize();
  if (status != null) {
    term.writeln('In-band resize support: ${status.status.name}\r');
  } else {
    term.writeln('In-band resize query timed out\r');
  }

  term
    ..enableRawMode()
    ..enableInBandResize()
    ..writeln('Window resize monitor. Press any key to exit.\r')
    ..writeln('Resize terminal to see events...\r\n');

  while (true) {
    final event = await term.read<Event>();

    if (event is WindowResizeEvent) {
      term.writeln('Resize: ${event.widthChars}x${event.heightChars} chars');
      if (event.widthPixels > 0 || event.heightPixels > 0) {
        term.writeln('        ${event.widthPixels}x${event.heightPixels} pixels');
      }
      term.writeln('\r');
    } else if (event is KeyEvent) {
      break;
    } else {
      term.writeln('Event: $event\r');
    }
  }

  term
    ..writeln('\nExiting...\r')
    ..disableInBandResize()
    ..disableRawMode();
  await term.flushThenExit(0);
}
