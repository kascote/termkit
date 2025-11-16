import '../events/event_base.dart';
import '../events/key_event.dart';
import 'parser_base.dart';

/// Parse a single character
Event parseChar(String char, {bool escO = false}) {
  if (escO) {
    return switch (char) {
      'P' => const KeyEvent(KeyCode.named(KeyCodeName.f1)),
      'Q' => const KeyEvent(KeyCode.named(KeyCodeName.f2)),
      'R' => const KeyEvent(KeyCode.named(KeyCodeName.f3)),
      'S' => const KeyEvent(KeyCode.named(KeyCodeName.f4)),
      _ => const KeyEvent(KeyCode.named(KeyCodeName.none)),
    };
  }
  return switch (char) {
    '\r' || '\n' => const KeyEvent(KeyCode.named(KeyCodeName.enter)),
    '\t' => const KeyEvent(KeyCode.named(KeyCodeName.tab)),
    '\x08' || '\x7f' => const KeyEvent(KeyCode.named(KeyCodeName.backSpace)),
    '\x1b' => const KeyEvent(KeyCode.named(KeyCodeName.escape)),
    '\x00' => const KeyEvent(KeyCode.named(KeyCodeName.none)),
    _ => ctrlOrKey(char),
  };
}
