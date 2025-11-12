import 'dart:convert';

import '../events.dart';
import '../events_types.dart';
import '../extensions/string_extension.dart';
import '../sequences/key_parser.dart';

/// Parse a control sequence
/// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#legacy-functional-keys
Event parseCSISequence(List<String> parameters, int ignoredParameterCount, String char) {
  return switch (char) {
    'A' => _parseKeyAndModifiers(KeyCodeName.up, parameters.length == 2 ? parameters[1] : ''),
    'B' => _parseKeyAndModifiers(KeyCodeName.down, parameters.length == 2 ? parameters[1] : ''),
    'C' => _parseKeyAndModifiers(KeyCodeName.right, parameters.length == 2 ? parameters[1] : ''),
    'D' => _parseKeyAndModifiers(KeyCodeName.left, parameters.length == 2 ? parameters[1] : ''),
    'F' => _parseKeyAndModifiers(KeyCodeName.end, parameters.length == 2 ? parameters[1] : ''),
    'H' => _parseKeyAndModifiers(KeyCodeName.home, parameters.length == 2 ? parameters[1] : ''),
    'P' => _parseKeyAndModifiers(KeyCodeName.f1, parameters.length == 2 ? parameters[1] : ''),
    'Q' => _parseKeyAndModifiers(KeyCodeName.f2, parameters.length == 2 ? parameters[1] : ''),
    'S' => _parseKeyAndModifiers(KeyCodeName.f4, parameters.length == 2 ? parameters[1] : ''),
    'Z' => _parseKeyAndModifiers(KeyCodeName.backTab, parameters.length == 2 ? parameters[1] : ''),
    'M' || 'm' when parameters.firstOrNull == '<' => sgrMouseParser(parameters, char, ignoredParameterCount),
    'I' => const FocusEvent(),
    'O' => const FocusEvent(hasFocus: false),
    'u' => _parseKeyboardEnhancedMode(parameters, char),
    'c' => _primaryDeviceAttributes(parameters, char),
    '~' => _parseSpecialKeyCode(parameters, char),
    'R' => _parseCursorPosition(parameters),
    'y' => _parseDECRPMStatus(parameters),
    't' => _parseWindowSize(parameters),
    _ => const NoneEvent(),
  };
}

Event _parseKeyAndModifiers(KeyCodeName name, String parameters) {
  final (modifier, event) = modifierAndEventParser(parameters);
  return KeyEvent(
    KeyCode(name: name),
    modifiers: modifier,
    eventType: event,
  );
}

// This function parses `CSI … u` sequences. These are sequences defined in either
// the `CSI u` (a.k.a. "Fix Keyboard Input on Terminals - Please", https://www.leonerd.org.uk/hacks/fixterms/)
// or Kitty Keyboard Protocol (https://sw.kovidgoyal.net/kitty/keyboard-protocol/) specifications.
// This CSI sequence is a tuple of semicolon-separated numbers.
Event _parseKeyboardEnhancedMode(List<String> parameters, String char) {
  if (parameters.isEmpty) return const NoneEvent();

  if (parameters[0] == '?') {
    return keyboardEnhancedCodeParser(parameters[1]);
  }

  // https://sw.kovidgoyal.net/kitty/keyboard-protocol/#an-overview
  //
  // In `CSI u`, this is parsed as:
  //
  //     CSI codePoint ; modifiers u
  //     codePoint: ASCII Dec value
  //
  // The Kitty Keyboard Protocol extends this with optional components that can be
  // enabled progressively. The full sequence is parsed as:
  //
  //     CSI unicode-key-code:alternate-key-codes ; modifiers:event-type ; text-as-codepoints u
  //
  // The protocol define that can send the base layout key too with the following sequence when
  // there is no shifted key:
  //
  //     CSI unicode-key-code::base-layout-key
  //
  // WezTerm is using it on some cases (Shift-Backspace, Shift-\, etc)

  final codePoints = parameters.first.split(':');
  final codePoint = int.tryParse(codePoints.firstOrNull ?? '');
  final shiftedKey = int.tryParse(codePoints.elementAtOrNull(1) ?? '');
  final baseLayout = int.tryParse(codePoints.elementAtOrNull(2) ?? '');
  // the first element is the only required
  if (codePoint == null) return const NoneEvent();

  final (modifierMask, eventKind) = parameters.length == 1 ? (null, null) : modifierAndKindParse(parameters[1]);
  var modifiers = modifierMask == null ? KeyModifiers.empty() : modifierParser(modifierMask);
  final kind = eventKindParser(eventKind);
  final stateFromModifiers = modifiersToStateParser(modifierMask);
  var (keyCode, stateFromKeyCode) = functionalKeyCodeParser(codePoint);

  if (keyCode == const KeyCode()) {
    final c = StringExtension.tryFromCharCode(codePoint);
    if (c == null) return const NoneEvent();

    keyCode = switch (codePoint) {
      0x1b => const KeyCode(name: KeyCodeName.escape),
      0xd => const KeyCode(name: KeyCodeName.enter),
      // if the terminal is in raw mode, the enter key sends \r
      // we need to handle this case. How to receive the raw mode status?
      0xa => const KeyCode(name: KeyCodeName.enter),
      0x9 =>
        modifiers.has(KeyModifiers.shift)
            ? const KeyCode(name: KeyCodeName.backTab)
            : const KeyCode(name: KeyCodeName.tab),
      0x7f => const KeyCode(name: KeyCodeName.backSpace),
      _ => KeyCode(char: String.fromCharCode(codePoint)),
    };
    stateFromKeyCode = KeyEventState.none();
  }

  modifiers = switch (keyCode.modifiers) {
    ModifierKeyCode.leftAlt || ModifierKeyCode.rightAlt => modifiers.add(KeyModifiers.alt),
    ModifierKeyCode.leftControl || ModifierKeyCode.rightControl => modifiers.add(KeyModifiers.ctrl),
    ModifierKeyCode.leftShift || ModifierKeyCode.rightShift => modifiers.add(KeyModifiers.shift),
    ModifierKeyCode.leftSuper || ModifierKeyCode.rightSuper => modifiers.add(KeyModifiers.superKey),
    ModifierKeyCode.leftHyper || ModifierKeyCode.rightHyper => modifiers.add(KeyModifiers.hyper),
    ModifierKeyCode.leftMeta || ModifierKeyCode.rightMeta => modifiers.add(KeyModifiers.meta),
    _ => modifiers,
  };

  if (modifiers.has(KeyModifiers.shift)) {
    if (shiftedKey != null) {
      keyCode = KeyCode(char: String.fromCharCode(shiftedKey));
      modifiers.add(KeyModifiers.shift);
    }
  }
  if (baseLayout != null) keyCode = keyCode.copyWith(baseLayoutKey: baseLayout);

  return KeyEvent(
    keyCode,
    modifiers: modifiers,
    eventType: kind,
    eventState: stateFromKeyCode == KeyEventState.none() ? stateFromModifiers : stateFromKeyCode,
  );
}

Event _primaryDeviceAttributes(List<String> parameters, String char) {
  if (parameters.isEmpty) return const NoneEvent();
  if (parameters[0] != '?') return const NoneEvent();

  final params = parameters.sublist(1);

  // Parse device type and capabilities
  final (type, capabilities) = switch (params) {
    ['1', '0'] => (DeviceAttributeType.vt101WithNoOptions, <DeviceAttributeParams>[]),
    ['6'] => (DeviceAttributeType.vt102, <DeviceAttributeParams>[]),
    ['1', '2'] => (DeviceAttributeType.vt100WithAdvancedVideoOption, <DeviceAttributeParams>[]),
    ['62', ...] => (DeviceAttributeType.vt220, _parseDeviceParams(params.sublist(1))),
    ['63', ...] => (DeviceAttributeType.vt320, _parseDeviceParams(params.sublist(1))),
    ['64', ...] => (DeviceAttributeType.vt420, _parseDeviceParams(params.sublist(1))),
    ['65', ...] => (DeviceAttributeType.vt500, _parseDeviceParams(params.sublist(1))),
    _ => (DeviceAttributeType.unknown, <DeviceAttributeParams>[]),
  };

  return PrimaryDeviceAttributesEvent(type, capabilities);
}

List<DeviceAttributeParams> _parseDeviceParams(List<String> params) {
  return params.fold(<DeviceAttributeParams>[], (acc, p) {
    if (p.isEmpty) return acc;
    final code = DeviceAttributeParams.values.firstWhere(
      (e) => e.value == int.parse(p),
      orElse: () => DeviceAttributeParams.unknown,
    );
    if (code != DeviceAttributeParams.unknown) return acc..add(code);
    return acc;
  });
}

Event _parseSpecialKeyCode(List<String> parameters, String char) {
  if (parameters.isEmpty) return const NoneEvent();

  final (modifierMask, eventKind) = parameters.length == 1 ? (null, null) : modifierAndKindParse(parameters[1]);
  final modifier = modifierMask == null ? KeyModifiers.empty() : modifierParser(modifierMask);
  final eventType = eventKindParser(eventKind);
  final state = modifiersToStateParser(modifierMask);
  final keyCode = int.parse(parameters.first);

  final key = switch (keyCode) {
    1 || 7 => KeyCodeName.home,
    2 => KeyCodeName.insert,
    3 => KeyCodeName.delete,
    4 || 8 => KeyCodeName.end,
    5 => KeyCodeName.pageUp,
    6 => KeyCodeName.pageDown,
    11 => KeyCodeName.f1,
    12 => KeyCodeName.f2,
    13 => KeyCodeName.f3,
    14 => KeyCodeName.f4,
    15 => KeyCodeName.f5,
    17 => KeyCodeName.f6,
    18 => KeyCodeName.f7,
    19 => KeyCodeName.f8,
    20 => KeyCodeName.f9,
    21 => KeyCodeName.f10,
    23 => KeyCodeName.f11,
    24 => KeyCodeName.f12,
    25 => KeyCodeName.f13,
    26 => KeyCodeName.f14,
    28 => KeyCodeName.f15,
    29 => KeyCodeName.f16,
    31 => KeyCodeName.f17,
    32 => KeyCodeName.f18,
    33 => KeyCodeName.f19,
    34 => KeyCodeName.f20,
    _ => null,
  };

  if (key == null) return const NoneEvent();

  return KeyEvent(
    KeyCode(name: key),
    modifiers: modifier,
    eventType: eventType,
    eventState: state,
  );
}

Event _parseCursorPosition(List<String> parameters) {
  if (parameters.isEmpty) return const NoneEvent();
  if (parameters.length != 2) return const NoneEvent();

  final x = int.tryParse(parameters[0]);
  final y = int.tryParse(parameters[1]);
  if (x == null || y == null) return const NoneEvent();
  return CursorPositionEvent(x, y);
}

Event _parseDECRPMStatus(List<String> parameters) {
  switch (parameters) {
    case ['?', '2026', ...]:
      return QuerySyncUpdateEvent(int.tryParse(parameters[2]) ?? 0);
    case ['?', '2027', ...]:
      return UnicodeCoreEvent(int.tryParse(parameters[2]) ?? 0);
    default:
      return const NoneEvent();
  }
}

Event _parseWindowSize(List<String> parameters) {
  switch (parameters) {
    case ['4', ...]:
      final width = int.tryParse(parameters[1]) ?? -1;
      final height = int.tryParse(parameters[2]) ?? -1;
      return QueryTerminalWindowSizeEvent(width, height);
    default:
      return const NoneEvent();
  }
}

/// Parse bracketed paste from raw sequence bytes.
///
/// Extracts content between CSI 200~ and CSI 201~ markers.
/// State machine guarantees both markers are present.
/// Note: Initial ESC is not in sequenceBytes (starts with '['),
/// but ESC before end marker IS included.
Event parseBracketedPaste(List<int> sequenceBytes) {
  // sequenceBytes = [ '[', '2', '0', '0', '~', ...content..., ESC, '[', '2', '0', '1', '~' ]
  final content = sequenceBytes.sublist(5, sequenceBytes.length - 6);
  final text = utf8.decode(content, allowMalformed: true);
  return PasteEvent(text);
}
