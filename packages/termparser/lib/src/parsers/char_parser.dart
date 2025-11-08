import '../events.dart';
import '../events_types.dart';
import 'parser_base.dart';

/// Parse a single character
Event? parseChar(String char, {bool escO = false}) {
  if (escO) {
    return switch (char) {
      'P' => const KeyEvent(KeyCode(name: KeyCodeName.f1)),
      'Q' => const KeyEvent(KeyCode(name: KeyCodeName.f2)),
      'R' => const KeyEvent(KeyCode(name: KeyCodeName.f3)),
      'S' => const KeyEvent(KeyCode(name: KeyCodeName.f4)),
      _ => const KeyEvent(KeyCode()), // none
    };
  }
  return switch (char) {
    '\r' || '\n' => const KeyEvent(KeyCode(name: KeyCodeName.enter)),
    '\t' => const KeyEvent(KeyCode(name: KeyCodeName.tab)),
    '\x08' || '\x7f' => const KeyEvent(KeyCode(name: KeyCodeName.backSpace)),
    '\x1b' => const KeyEvent(KeyCode(name: KeyCodeName.escape)),
    '\x00' => const KeyEvent(KeyCode()), // none
    _ => ctrlOrKey(char),
  };
}
