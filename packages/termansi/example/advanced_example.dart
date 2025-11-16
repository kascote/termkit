import 'dart:convert';
import 'dart:io';

import 'package:termansi/termansi.dart';

void main() {
  // Save cursor position & hide cursor
  stdout
    ..write(Cursor.savePosition)
    ..write(Cursor.hide)
    // Alternate screen buffer (common in full-screen TUIs)
    ..write(Term.enableAlternateScreen)
    ..write(Erase.screenAll)
    ..write(Cursor.moveTo(1, 1))
    // Draw header
    ..write(Color.trueColorBg(50, 50, 100))
    ..write(Color.white)
    ..write(Text.bold)
    ..write('Advanced Terminal Features Demo')
    ..write(' ' * (80 - 31)) // Pad to 80 cols
    ..writeln(Color.reset)
    // Mouse events demo
    ..write(Cursor.moveTo(3, 1))
    ..writeln('${Text.bold}Mouse Events:${Text.resetBold}')
    ..writeln('  Enabling mouse tracking...')
    ..write(Term.enableMouseEvents) // Track all mouse events
    ..write(Term.enableMousePixelEvents); // SGR extended mode

  sleep(const Duration(seconds: 2));

  stdout
    ..write(Cursor.moveTo(6, 1))
    ..writeln('  (Move mouse to see events in real terminal)')
    ..writeln('  Disabling in 3s...');

  sleep(const Duration(seconds: 3));

  stdout
    ..write(Term.disableMouseEvents)
    ..write(Term.disableMousePixelsEvents)
    // Keyboard protocol
    ..write(Cursor.moveTo(10, 1))
    ..writeln('${Text.bold}Keyboard Protocol:${Text.resetBold}')
    ..write('  Enhanced keyboard: ')
    ..write(Term.pushKeyboardCapabilities(3)) // 1=disambiguate + 2=reportEvents
    ..writeln('enabled');

  sleep(const Duration(seconds: 2));

  // Clipboard
  stdout
    ..write(Cursor.moveTo(13, 1))
    ..writeln('${Text.bold}Clipboard:${Text.resetBold}')
    ..write('  Setting clipboard: ')
    ..write(Term.clipboard('c', base64.encode(utf8.encode('Hello from TermAnsi!'))))
    ..writeln('done');

  sleep(const Duration(seconds: 2));

  // Cursor operations
  stdout
    ..write(Cursor.moveTo(16, 1))
    ..writeln('${Text.bold}Cursor Operations:${Text.resetBold}')
    // Show cursor briefly
    ..write(Cursor.show);

  sleep(const Duration(milliseconds: 500));

  // Save position, move around, restore
  stdout
    ..write(Cursor.moveTo(17, 3))
    ..write('Saving position...')
    ..write(Cursor.savePosition);

  sleep(const Duration(milliseconds: 500));

  stdout
    ..write(Cursor.moveTo(20, 10))
    ..write('Moved away...');

  sleep(const Duration(milliseconds: 500));

  stdout
    ..write(Cursor.restorePosition)
    ..write(' Restored!          '); // Overwrite previous text

  sleep(const Duration(seconds: 1));

  // Synchronized updates (reduces flicker)
  stdout
    ..write(Cursor.moveTo(19, 1))
    ..writeln('${Text.bold}Synchronized Update:${Text.resetBold}')
    ..write(Term.enableSyncUpdate);

  // Multiple writes happen atomically
  for (var i = 0; i < 5; i++) {
    stdout
      ..write(Cursor.moveTo(20 + i, 3))
      ..write('${Color.color256Fg(40 + i * 10)}Line $i${Color.reset}');
  }

  stdout.write(Term.disableSyncUpdate);

  sleep(const Duration(seconds: 2));

  // Hyperlinks
  stdout
    ..write(Cursor.moveTo(26, 1))
    ..writeln('${Text.bold}Hyperlinks:${Text.resetBold}')
    ..write('  ')
    ..writeln(Term.hyperLink('https://github.com/kascote/termkit', 'TermKit Project'))
    ..write('  ')
    ..writeln(Term.hyperLink('https://pub.dev/packages/termansi', 'pub.dev page'));

  sleep(const Duration(seconds: 2));

  // Cleanup
  stdout
    ..write(Cursor.moveTo(30, 1))
    ..write('Cleaning up in 2s...');

  sleep(const Duration(seconds: 2));

  // Restore keyboard
  stdout
    ..write(Term.popKeyboardCapabilities())
    // Restore screen
    ..write(Erase.screenAll)
    ..write(Term.disableAlternateScreen)
    ..write(Cursor.restorePosition)
    ..write(Cursor.show)
    ..writeln('${Color.green}Demo complete!${Color.reset}');
}
