import 'package:termparser/src/sequences.dart';

import '../extensions/int_extension.dart';
import 'key_sequence.dart';
import 'mouse_data.dart';

int _parseInt(String value) => int.tryParse(value) ?? 0;

/// Parse the modifier and event from the parameters
(KeyModifiers, KeyEventType) modifierAndEventParser(String value) {
  final split = value.split(':');

  if (split.isEmpty) return (KeyModifiers.empty(), KeyEventType.keyPress);

  final modifier = int.tryParse(split[0]) ?? 0;
  final event = split.length == 2 ? int.tryParse(split[1]) : null;

  return (modifierParser(modifier), eventKindParser(event ?? 1));
}

/// Parse the modifier keys
KeyModifiers modifierParser(int modifier) {
  final mod = modifier.saturatingSub(1);
  var modifiers = KeyModifiers.empty();
  if (mod & 1 != 0) modifiers = modifiers.add(KeyModifiers.shift);
  if (mod & 2 != 0) modifiers = modifiers.add(KeyModifiers.alt);
  if (mod & 4 != 0) modifiers = modifiers.add(KeyModifiers.ctrl);
  if (mod & 8 != 0) modifiers = modifiers.add(KeyModifiers.superKey);
  if (mod & 16 != 0) modifiers = modifiers.add(KeyModifiers.hyper);
  if (mod & 32 != 0) modifiers = modifiers.add(KeyModifiers.meta);

  return modifiers;
}

/// Parse the type of event received
KeyEventType eventKindParser(int? eventKindType) {
  return switch (eventKindType) {
    1 => KeyEventType.keyPress,
    2 => KeyEventType.keyRepeat,
    3 => KeyEventType.keyRelease,
    _ => KeyEventType.keyPress,
  };
}

const _motion = 0x20; // 0010_0000;
const _buttonBits = 0xC3; // 1100_0011;
const _mouseModShift = 0x04; // 0000_0100;
const _mouseModAlt = 0x08; // 0000_1000;
const _mouseModCtrl = 0x10; // 0001_0000;

/// Parse SGR mouse
Sequence sgrMouseParser(List<String> parameters, String charFinal, int ignoredParameterCount) {
  if (parameters.length != 3) return const NoneSequence();

  var action = switch (charFinal) {
    'M' => MouseButtonAction.down,
    'm' => MouseButtonAction.up,
    _ => MouseButtonAction.none,
  };

  final p1 = _parseInt(parameters[0]);
  final btn = p1 & _buttonBits;
  var mods = 0;

  if (p1.isSet(_motion)) action = MouseButtonAction.moved;
  if (p1.isSet(_mouseModShift)) mods |= KeyModifiers.shift;
  if (p1.isSet(_mouseModAlt)) mods |= KeyModifiers.alt;
  if (p1.isSet(_mouseModCtrl)) mods |= KeyModifiers.ctrl;
  final button = switch (btn) {
    0x00 => MouseButton.left,
    0x01 => MouseButton.middle,
    0x02 => MouseButton.right,
    _ => MouseButton.none,
  };

  return MouseSequence(
    _parseInt(parameters[1]),
    _parseInt(parameters[2]),
    MouseButtonEvent(button, action),
    modifiers: KeyModifiers(mods),
  );
}

/// Parse the keyboard enhanced mode
KeyboardEnhancementFlags parseKeyboardEnhancedCode(String mode) {
  final bits = int.tryParse(mode) ?? 0;
  var flags = KeyboardEnhancementFlags.empty();

  if (bits.isSet(KeyboardEnhancementFlags.disambiguateEscapeCodes)) {
    flags = flags.add(KeyboardEnhancementFlags.disambiguateEscapeCodes);
  }
  if (bits.isSet(KeyboardEnhancementFlags.reportEventTypes)) {
    flags = flags.add(KeyboardEnhancementFlags.reportEventTypes);
  }
  if (bits.isSet(KeyboardEnhancementFlags.reportAlternateKeys)) {
    flags = flags.add(KeyboardEnhancementFlags.reportAlternateKeys);
  }
  if (bits.isSet(KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes)) {
    flags = flags.add(KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes);
  }

  return flags;
}
