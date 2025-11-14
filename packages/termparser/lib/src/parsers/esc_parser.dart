import '../events/event_base.dart';
import '../events/key_event.dart';

/// Parse an escape sequence
Event? parseESCSequence(String char) {
  // EscO[P-S] is handled in the Performer, see parse_char & esc_o argument
  // No need to handle other cases here? It's just Alt+$char
  return KeyEvent(KeyCode.char(char), modifiers: const KeyModifiers(KeyModifiers.alt));
}
