import 'package:termparser/src/extensions/string_extension.dart';

import '../events.dart';
import '../events_types.dart';
import '../extensions/int_extension.dart';

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
const _mouseWheelUp = 0x40; // 0100_0000;
const _mouseWheelDown = 0x41; // 0100_0001;
const _mouseWheelLeft = 0x42; // 0100_0010;
const _mouseWheelRight = 0x43; // 0100_0011;

/// Parse SGR mouse
Event sgrMouseParser(List<String> parameters, String charFinal, int ignoredParameterCount) {
  if (parameters.length > 4) return const NoneEvent();

  var action = switch (charFinal) {
    'M' => MouseButtonAction.down,
    'm' => MouseButtonAction.up,
    _ => MouseButtonAction.none,
  };

  final p1 = parameters[0].parseInt();
  final btn = p1 & _buttonBits;
  var mods = 0;

  if (p1.isSet(_motion)) action = MouseButtonAction.moved;
  if (p1.isSet(_mouseWheelUp)) action = MouseButtonAction.wheelUp;
  if (p1.isSet(_mouseWheelDown)) action = MouseButtonAction.wheelDown;
  if (p1.isSet(_mouseWheelLeft)) action = MouseButtonAction.wheelLeft;
  if (p1.isSet(_mouseWheelRight)) action = MouseButtonAction.wheelRight;
  if (p1.isSet(_mouseModShift)) mods |= KeyModifiers.shift;
  if (p1.isSet(_mouseModAlt)) mods |= KeyModifiers.alt;
  if (p1.isSet(_mouseModCtrl)) mods |= KeyModifiers.ctrl;
  final button = switch (btn) {
    0x00 => MouseButtonKind.left,
    0x01 => MouseButtonKind.middle,
    0x02 => MouseButtonKind.right,
    _ => MouseButtonKind.none,
  };

  return MouseEvent(
    parameters[1].parseInt(),
    parameters[2].parseInt(),
    MouseButton(button, action),
    modifiers: KeyModifiers(mods),
  );
}

/// Parse the keyboard enhanced mode
KeyboardEnhancementFlagsEvent keyboardEnhancedCodeParser(String mode) {
  final bits = int.tryParse(mode) ?? 0;
  var flags = KeyboardEnhancementFlagsEvent.empty();

  if (bits.isSet(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes)) {
    flags = flags.add(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes);
  }
  if (bits.isSet(KeyboardEnhancementFlagsEvent.reportEventTypes)) {
    flags = flags.add(KeyboardEnhancementFlagsEvent.reportEventTypes);
  }
  if (bits.isSet(KeyboardEnhancementFlagsEvent.reportAlternateKeys)) {
    flags = flags.add(KeyboardEnhancementFlagsEvent.reportAlternateKeys);
  }
  if (bits.isSet(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes)) {
    flags = flags.add(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes);
  }

  return flags;
}

/// Split the modifier applied and the kind of event
(int?, int?) modifierAndKindParse(String modifierAndKey) {
  final split = modifierAndKey.split(':');
  final modifier = int.parse(split[0]);
  final eventType = (split.length > 1) ? int.parse(split[1]) : null;

  // if there is no even type, by default is keyPress
  return (modifier, eventType ?? 1);
}

/// Parse the modifier keys to state
KeyEventState modifiersToStateParser(int? modifierMask) {
  final mod = (modifierMask ?? 0).saturatingSub(1);
  var state = KeyEventState.none();
  if (mod & 64 != 0) state = state.add(KeyEventState.capsLock());
  if (mod & 128 != 0) state = state.add(KeyEventState.numLock());
  return state;
}

/// Translate the enhanced keyboard code to a functional key code
(KeyCode, KeyEventState) functionalKeyCodeParser(int codePoint) {
  var keyCode = switch (codePoint) {
    57399 => const KeyCode(char: '0'),
    57400 => const KeyCode(char: '1'),
    57401 => const KeyCode(char: '2'),
    57402 => const KeyCode(char: '3'),
    57403 => const KeyCode(char: '4'),
    57404 => const KeyCode(char: '5'),
    57405 => const KeyCode(char: '6'),
    57406 => const KeyCode(char: '7'),
    57407 => const KeyCode(char: '8'),
    57408 => const KeyCode(char: '9'),
    57409 => const KeyCode(char: '.'),
    57410 => const KeyCode(char: '/'),
    57411 => const KeyCode(char: '*'),
    57412 => const KeyCode(char: '-'),
    57413 => const KeyCode(char: '+'),
    57414 => const KeyCode(name: KeyCodeName.enter),
    57415 => const KeyCode(char: '='),
    57416 => const KeyCode(char: ','),
    57417 => const KeyCode(name: KeyCodeName.left),
    57418 => const KeyCode(name: KeyCodeName.right),
    57419 => const KeyCode(name: KeyCodeName.up),
    57420 => const KeyCode(name: KeyCodeName.down),
    57421 => const KeyCode(name: KeyCodeName.pageUp),
    57422 => const KeyCode(name: KeyCodeName.pageDown),
    57423 => const KeyCode(name: KeyCodeName.home),
    57424 => const KeyCode(name: KeyCodeName.end),
    57425 => const KeyCode(name: KeyCodeName.insert),
    57426 => const KeyCode(name: KeyCodeName.delete),
    57427 => const KeyCode(name: KeyCodeName.keypadBegin),
    _ => null,
  };

  if (keyCode != null) return (keyCode, KeyEventState.keypad());

  keyCode = switch (codePoint) {
    57358 => const KeyCode(name: KeyCodeName.capsLock),
    57359 => const KeyCode(name: KeyCodeName.scrollLock),
    57360 => const KeyCode(name: KeyCodeName.numLock),
    57361 => const KeyCode(name: KeyCodeName.printScreen),
    57362 => const KeyCode(name: KeyCodeName.pause),
    57363 => const KeyCode(name: KeyCodeName.menu),
    57376 => const KeyCode(name: KeyCodeName.f13),
    57377 => const KeyCode(name: KeyCodeName.f14),
    57378 => const KeyCode(name: KeyCodeName.f15),
    57379 => const KeyCode(name: KeyCodeName.f16),
    57380 => const KeyCode(name: KeyCodeName.f17),
    57381 => const KeyCode(name: KeyCodeName.f18),
    57382 => const KeyCode(name: KeyCodeName.f19),
    57383 => const KeyCode(name: KeyCodeName.f20),
    57384 => const KeyCode(name: KeyCodeName.f21),
    57385 => const KeyCode(name: KeyCodeName.f22),
    57386 => const KeyCode(name: KeyCodeName.f23),
    57387 => const KeyCode(name: KeyCodeName.f24),
    57388 => const KeyCode(name: KeyCodeName.f25),
    57389 => const KeyCode(name: KeyCodeName.f26),
    57390 => const KeyCode(name: KeyCodeName.f27),
    57391 => const KeyCode(name: KeyCodeName.f28),
    57392 => const KeyCode(name: KeyCodeName.f29),
    57393 => const KeyCode(name: KeyCodeName.f30),
    57394 => const KeyCode(name: KeyCodeName.f31),
    57395 => const KeyCode(name: KeyCodeName.f32),
    57396 => const KeyCode(name: KeyCodeName.f33),
    57397 => const KeyCode(name: KeyCodeName.f34),
    57398 => const KeyCode(name: KeyCodeName.f35),
    57428 => const KeyCode(media: MediaKeyCode.play),
    57429 => const KeyCode(media: MediaKeyCode.pause),
    57430 => const KeyCode(media: MediaKeyCode.playPause),
    57431 => const KeyCode(media: MediaKeyCode.reverse),
    57432 => const KeyCode(media: MediaKeyCode.stop),
    57433 => const KeyCode(media: MediaKeyCode.fastForward),
    57434 => const KeyCode(media: MediaKeyCode.rewind),
    57435 => const KeyCode(media: MediaKeyCode.trackNext),
    57436 => const KeyCode(media: MediaKeyCode.trackPrevious),
    57437 => const KeyCode(media: MediaKeyCode.record),
    57438 => const KeyCode(media: MediaKeyCode.lowerVolume),
    57439 => const KeyCode(media: MediaKeyCode.raiseVolume),
    57440 => const KeyCode(media: MediaKeyCode.muteVolume),
    57441 => const KeyCode(modifiers: ModifierKeyCode.leftShift),
    57442 => const KeyCode(modifiers: ModifierKeyCode.leftControl),
    57443 => const KeyCode(modifiers: ModifierKeyCode.leftAlt),
    57444 => const KeyCode(modifiers: ModifierKeyCode.leftSuper),
    57445 => const KeyCode(modifiers: ModifierKeyCode.leftHyper),
    57446 => const KeyCode(modifiers: ModifierKeyCode.leftMeta),
    57447 => const KeyCode(modifiers: ModifierKeyCode.rightShift),
    57448 => const KeyCode(modifiers: ModifierKeyCode.rightControl),
    57449 => const KeyCode(modifiers: ModifierKeyCode.rightAlt),
    57450 => const KeyCode(modifiers: ModifierKeyCode.rightSuper),
    57451 => const KeyCode(modifiers: ModifierKeyCode.rightHyper),
    57452 => const KeyCode(modifiers: ModifierKeyCode.rightMeta),
    57453 => const KeyCode(modifiers: ModifierKeyCode.isoLevel3Shift),
    57454 => const KeyCode(modifiers: ModifierKeyCode.isoLevel5Shift),
    _ => null,
  };

  if (keyCode != null) return (keyCode, KeyEventState.none());

  return (const KeyCode(), const KeyEventState(0));
}
