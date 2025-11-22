import '../engine/parameters.dart';
import '../events/event_base.dart';
import '../events/focus_event.dart';
import '../events/internal_events.dart';
import '../events/key_event.dart';
import '../events/key_support.dart';
import '../events/response_events.dart';
import '../extensions/string_extension.dart';
import 'key_parser.dart';

/// Parse a control sequence
/// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#legacy-functional-keys
Event parseCSISequence(Parameters params, String char) {
  return switch (char) {
    'A' => _parseKeyAndModifiers(KeyCodeName.up, params.values.length == 2 ? params.values[1] : ''),
    'B' => _parseKeyAndModifiers(KeyCodeName.down, params.values.length == 2 ? params.values[1] : ''),
    'C' => _parseKeyAndModifiers(KeyCodeName.right, params.values.length == 2 ? params.values[1] : ''),
    'D' => _parseKeyAndModifiers(KeyCodeName.left, params.values.length == 2 ? params.values[1] : ''),
    'F' => _parseKeyAndModifiers(KeyCodeName.end, params.values.length == 2 ? params.values[1] : ''),
    'H' => _parseKeyAndModifiers(KeyCodeName.home, params.values.length == 2 ? params.values[1] : ''),
    'P' => _parseKeyAndModifiers(KeyCodeName.f1, params.values.length == 2 ? params.values[1] : ''),
    'Q' => _parseKeyAndModifiers(KeyCodeName.f2, params.values.length == 2 ? params.values[1] : ''),
    'S' => _parseKeyAndModifiers(KeyCodeName.f4, params.values.length == 2 ? params.values[1] : ''),
    'Z' => _parseKeyAndModifiers(KeyCodeName.backTab, params.values.length == 2 ? params.values[1] : ''),
    'M' || 'm' when params.values.firstOrNull == '<' => sgrMouseParser(params, char),
    'I' => const FocusEvent(),
    'O' => const FocusEvent(hasFocus: false),
    'u' => _parseKeyboardEnhancedMode(params, char),
    'c' => _primaryDeviceAttributes(params, char),
    '~' => _parseSpecialKeyCode(params, char),
    'R' => _parseCursorPosition(params),
    'y' => _parseDECRPMStatus(params),
    't' => _parseWindowSize(params),
    _ => const NoneEvent(),
  };
}

Event _parseKeyAndModifiers(KeyCodeName name, String parameters) {
  final (modifier, event) = modifierAndEventParser(parameters);
  return KeyEvent(
    KeyCode.named(name),
    modifiers: modifier,
    eventType: event,
  );
}

// This function parses `CSI … u` sequences. These are sequences defined in either
// the `CSI u` (a.k.a. "Fix Keyboard Input on Terminals - Please", https://www.leonerd.org.uk/hacks/fixterms/)
// or Kitty Keyboard Protocol (https://sw.kovidgoyal.net/kitty/keyboard-protocol/) specifications.
// This CSI sequence is a tuple of semicolon-separated numbers.
Event _parseKeyboardEnhancedMode(Parameters params, String char) {
  if (params.values.isEmpty) return const NoneEvent();

  if (params.values[0] == '?') {
    return keyboardEnhancedCodeParser(params.values[1]);
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

  final codePoints = params.values.first.split(':');
  final codePoint = int.tryParse(codePoints.firstOrNull ?? '');
  final shiftedKey = int.tryParse(codePoints.elementAtOrNull(1) ?? '');
  final baseLayout = int.tryParse(codePoints.elementAtOrNull(2) ?? '');
  // the first element is the only required
  if (codePoint == null) return const NoneEvent();

  final (modifierMask, eventKind) = params.values.length == 1 ? (null, null) : modifierAndKindParse(params.values[1]);
  var modifiers = modifierMask == null ? KeyModifiers.none : modifierParser(modifierMask);
  final kind = eventKindParser(eventKind);
  // final stateFromModifiers = modifiersToStateParser(modifierMask);
  var (keyCode, baseModifier) = functionalKeyCodeParser(codePoint);
  modifiers = modifiers | baseModifier;

  if (keyCode == const KeyCode.named(KeyCodeName.none)) {
    final c = StringExtension.tryFromCharCode(codePoint);
    if (c == null) return const NoneEvent();

    keyCode = switch (codePoint) {
      0x1b => const KeyCode.named(KeyCodeName.escape),
      0xd => const KeyCode.named(KeyCodeName.enter),
      // if the terminal is in raw mode, the enter key sends \r
      // we need to handle this case. How to receive the raw mode status?
      0xa => const KeyCode.named(KeyCodeName.enter),
      0x9 =>
        modifiers.has(KeyModifiers.shift)
            ? const KeyCode.named(KeyCodeName.backTab)
            : const KeyCode.named(KeyCodeName.tab),
      0x7f => const KeyCode.named(KeyCodeName.backSpace),
      _ => KeyCode.char(String.fromCharCode(codePoint)),
    };
  }

  if (modifiers.has(KeyModifiers.shift)) {
    if (shiftedKey != null) {
      keyCode = KeyCode.char(String.fromCharCode(shiftedKey));
      modifiers = modifiers | KeyModifiers.shift;
    }
  }
  if (baseLayout != null) keyCode = keyCode.copyWith(baseLayoutKey: baseLayout);

  return KeyEvent(
    keyCode,
    modifiers: modifiers,
    eventType: kind,
  );
}

Event _primaryDeviceAttributes(Parameters params, String char) {
  if (params.values.isEmpty) return const NoneEvent();
  if (params.values[0] != '?') return const NoneEvent();

  final values = params.values.sublist(1);

  // Parse device type and capabilities
  final (type, capabilities) = switch (values) {
    ['1', '0'] => (DeviceAttributeType.vt101WithNoOptions, <DeviceAttributeParams>[]),
    ['6'] => (DeviceAttributeType.vt102, <DeviceAttributeParams>[]),
    ['1', '2'] => (DeviceAttributeType.vt100WithAdvancedVideoOption, <DeviceAttributeParams>[]),
    ['62', ...] => (DeviceAttributeType.vt220, _parseDeviceParams(values.sublist(1))),
    ['63', ...] => (DeviceAttributeType.vt320, _parseDeviceParams(values.sublist(1))),
    ['64', ...] => (DeviceAttributeType.vt420, _parseDeviceParams(values.sublist(1))),
    ['65', ...] => (DeviceAttributeType.vt500, _parseDeviceParams(values.sublist(1))),
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

Event _parseSpecialKeyCode(Parameters params, String char) {
  if (params.values.isEmpty) return const NoneEvent();

  final (modifierMask, eventKind) = params.values.length == 1 ? (null, null) : modifierAndKindParse(params.values[1]);
  final modifier = modifierMask == null ? KeyModifiers.none : modifierParser(modifierMask);
  final eventType = eventKindParser(eventKind);
  // final state = modifiersToStateParser(modifierMask);
  final keyCode = int.parse(params.values.first);

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
    KeyCode.named(key),
    modifiers: modifier,
    eventType: eventType,
    // eventState: state,
  );
}

Event _parseCursorPosition(Parameters params) {
  if (params.values.isEmpty) return const NoneEvent();
  if (params.values.length != 2) return const NoneEvent();

  final x = int.tryParse(params.values[0]);
  final y = int.tryParse(params.values[1]);
  if (x == null || y == null) return const NoneEvent();
  return CursorPositionEvent(x, y);
}

Event _parseDECRPMStatus(Parameters params) {
  switch (params.values) {
    case ['?', '2026', ...]:
      return QuerySyncUpdateEvent(int.tryParse(params.values[2]) ?? 0);
    case ['?', '2027', ...]:
      return UnicodeCoreEvent(int.tryParse(params.values[2]) ?? 0);
    default:
      return const NoneEvent();
  }
}

Event _parseWindowSize(Parameters params) {
  switch (params.values) {
    case ['4', ...]:
      final width = int.tryParse(params.values[1]) ?? -1;
      final height = int.tryParse(params.values[2]) ?? -1;
      return QueryTerminalWindowSizeEvent(width, height);
    default:
      return const NoneEvent();
  }
}
