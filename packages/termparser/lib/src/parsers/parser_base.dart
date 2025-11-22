import '../events/key_event.dart';
import '../events/key_support.dart';
import '../extensions/string_extension.dart';

/// Try to parse a hexadecimal string to int
int? tryParseInt(String value) {
  if (value.isEmpty || value.length > 4) return null;
  return value.padLeft(2, '0').substring(0, 2).tryParseHex();
}

/// Parse control character or regular key
KeyEvent ctrlOrKey(String char) {
  final code = char.codeUnitAt(0);
  return switch (code) {
    >= 0x01 && <= 0x1A => KeyEvent(
      KeyCode.char(String.fromCharCode(code - 0x01 + 0x61)),
      modifiers: KeyModifiers.ctrl,
    ),
    >= 0x1C && <= 0x1F => KeyEvent(
      KeyCode.char(String.fromCharCode(code - 0x1C + 0x34)),
      modifiers: KeyModifiers.ctrl,
    ),
    _ => KeyEvent(KeyCode.char(char)),
  };
}
