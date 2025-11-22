import 'package:termparser/src/extensions/string_extension.dart';

import '../engine/parameters.dart';
import '../events/event_base.dart';
import '../events/internal_events.dart';
import '../events/key_event.dart';
import '../events/key_support.dart';
import '../events/mouse_event.dart';
import '../events/response_events.dart';
import '../extensions/int_extension.dart';

/// Parse the modifier and event from the parameters
(KeyModifiers, KeyEventType) modifierAndEventParser(String value) {
  final split = value.split(':');

  if (split.isEmpty) return (KeyModifiers.none, KeyEventType.keyPress);

  final modifier = int.tryParse(split[0]) ?? 0;
  final event = split.length == 2 ? int.tryParse(split[1]) : null;

  return (modifierParser(modifier), eventKindParser(event ?? 1));
}

/// Parse the modifier keys
KeyModifiers modifierParser(int modifier) {
  final mod = modifier.saturatingSub(1);
  var modifiers = KeyModifiers.none;
  if (mod & 1 != 0) modifiers = modifiers | KeyModifiers.shift;
  if (mod & 2 != 0) modifiers = modifiers | KeyModifiers.alt;
  if (mod & 4 != 0) modifiers = modifiers | KeyModifiers.ctrl;
  if (mod & 8 != 0) modifiers = modifiers | KeyModifiers.superKey;
  if (mod & 16 != 0) modifiers = modifiers | KeyModifiers.hyper;
  if (mod & 32 != 0) modifiers = modifiers | KeyModifiers.meta;
  if (mod & 64 != 0) modifiers = modifiers | KeyModifiers.capsLock;
  if (mod & 128 != 0) modifiers = modifiers | KeyModifiers.keyPad;

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
Event sgrMouseParser(Parameters params, String charFinal) {
  // SGR mouse format: ESC [ < Pb ; Px ; Py M/m
  // params.values[0] = '<', params.values[1] = button, params.values[2] = x, params.values[3] = y
  // Can have trailing semicolon: ESC [ < Pb ; Px ; Py ; M (5 params, last empty)
  if (params.values.length < 4 || params.values.length > 5) return const NoneEvent();

  var action = switch (charFinal) {
    'M' => MouseButtonAction.down,
    'm' => MouseButtonAction.up,
    _ => MouseButtonAction.none,
  };

  final p1 = params.values[1].parseInt();
  final btn = p1 & _buttonBits;
  var modifiers = KeyModifiers.none;

  if (p1.isSet(_motion)) action = MouseButtonAction.moved;
  if (p1.isSet(_mouseWheelUp)) action = MouseButtonAction.wheelUp;
  if (p1.isSet(_mouseWheelDown)) action = MouseButtonAction.wheelDown;
  if (p1.isSet(_mouseWheelLeft)) action = MouseButtonAction.wheelLeft;
  if (p1.isSet(_mouseWheelRight)) action = MouseButtonAction.wheelRight;
  if (p1.isSet(_mouseModShift)) modifiers |= KeyModifiers.shift;
  if (p1.isSet(_mouseModAlt)) modifiers |= KeyModifiers.alt;
  if (p1.isSet(_mouseModCtrl)) modifiers |= KeyModifiers.ctrl;
  final button = switch (btn) {
    0x00 => MouseButtonKind.left,
    0x01 => MouseButtonKind.middle,
    0x02 => MouseButtonKind.right,
    _ => MouseButtonKind.none,
  };

  return MouseEvent(
    params.values[2].parseInt(),
    params.values[3].parseInt(),
    MouseButton(button, action),
    modifiers: modifiers,
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
// KeyEventState modifiersToStateParser(int? modifierMask) {
//   final mod = (modifierMask ?? 0).saturatingSub(1);
//   var state = KeyEventState.none();
//   if (mod & 64 != 0) state = state.add(KeyEventState.capsLock());
//   if (mod & 128 != 0) state = state.add(KeyEventState.numLock());
//   return state;
// }

/// Translate the enhanced keyboard code to a functional key code
(KeyCode, KeyModifiers) functionalKeyCodeParser(int codePoint) {
  var keyCode = switch (codePoint) {
    57399 => const KeyCode.char('0'),
    57400 => const KeyCode.char('1'),
    57401 => const KeyCode.char('2'),
    57402 => const KeyCode.char('3'),
    57403 => const KeyCode.char('4'),
    57404 => const KeyCode.char('5'),
    57405 => const KeyCode.char('6'),
    57406 => const KeyCode.char('7'),
    57407 => const KeyCode.char('8'),
    57408 => const KeyCode.char('9'),
    57409 => const KeyCode.char('.'),
    57410 => const KeyCode.char('/'),
    57411 => const KeyCode.char('*'),
    57412 => const KeyCode.char('-'),
    57413 => const KeyCode.char('+'),
    57414 => const KeyCode.named(KeyCodeName.enter),
    57415 => const KeyCode.char('='),
    57416 => const KeyCode.char(','),
    57417 => const KeyCode.named(KeyCodeName.left),
    57418 => const KeyCode.named(KeyCodeName.right),
    57419 => const KeyCode.named(KeyCodeName.up),
    57420 => const KeyCode.named(KeyCodeName.down),
    57421 => const KeyCode.named(KeyCodeName.pageUp),
    57422 => const KeyCode.named(KeyCodeName.pageDown),
    57423 => const KeyCode.named(KeyCodeName.home),
    57424 => const KeyCode.named(KeyCodeName.end),
    57425 => const KeyCode.named(KeyCodeName.insert),
    57426 => const KeyCode.named(KeyCodeName.delete),
    57427 => const KeyCode.named(KeyCodeName.keypadBegin),
    _ => null,
  };

  if (keyCode != null) {
    return (keyCode, KeyModifiers.keyPad);
  }

  keyCode = switch (codePoint) {
    57358 => const KeyCode.named(KeyCodeName.capsLock),
    57359 => const KeyCode.named(KeyCodeName.scrollLock),
    57360 => const KeyCode.named(KeyCodeName.numLock),
    57361 => const KeyCode.named(KeyCodeName.printScreen),
    57362 => const KeyCode.named(KeyCodeName.pause),
    57363 => const KeyCode.named(KeyCodeName.menu),
    57376 => const KeyCode.named(KeyCodeName.f13),
    57377 => const KeyCode.named(KeyCodeName.f14),
    57378 => const KeyCode.named(KeyCodeName.f15),
    57379 => const KeyCode.named(KeyCodeName.f16),
    57380 => const KeyCode.named(KeyCodeName.f17),
    57381 => const KeyCode.named(KeyCodeName.f18),
    57382 => const KeyCode.named(KeyCodeName.f19),
    57383 => const KeyCode.named(KeyCodeName.f20),
    57384 => const KeyCode.named(KeyCodeName.f21),
    57385 => const KeyCode.named(KeyCodeName.f22),
    57386 => const KeyCode.named(KeyCodeName.f23),
    57387 => const KeyCode.named(KeyCodeName.f24),
    57388 => const KeyCode.named(KeyCodeName.f25),
    57389 => const KeyCode.named(KeyCodeName.f26),
    57390 => const KeyCode.named(KeyCodeName.f27),
    57391 => const KeyCode.named(KeyCodeName.f28),
    57392 => const KeyCode.named(KeyCodeName.f29),
    57393 => const KeyCode.named(KeyCodeName.f30),
    57394 => const KeyCode.named(KeyCodeName.f31),
    57395 => const KeyCode.named(KeyCodeName.f32),
    57396 => const KeyCode.named(KeyCodeName.f33),
    57397 => const KeyCode.named(KeyCodeName.f34),
    57398 => const KeyCode.named(KeyCodeName.f35),
    57428 => const KeyCode.named(KeyCodeName.play),
    57429 => const KeyCode.named(KeyCodeName.pause),
    57430 => const KeyCode.named(KeyCodeName.playPause),
    57431 => const KeyCode.named(KeyCodeName.reverse),
    57432 => const KeyCode.named(KeyCodeName.stop),
    57433 => const KeyCode.named(KeyCodeName.fastForward),
    57434 => const KeyCode.named(KeyCodeName.rewind),
    57435 => const KeyCode.named(KeyCodeName.trackNext),
    57436 => const KeyCode.named(KeyCodeName.trackPrevious),
    57437 => const KeyCode.named(KeyCodeName.record),
    57438 => const KeyCode.named(KeyCodeName.lowerVolume),
    57439 => const KeyCode.named(KeyCodeName.raiseVolume),
    57440 => const KeyCode.named(KeyCodeName.muteVolume),
    _ => null,
  };

  if (keyCode != null) {
    return (keyCode, KeyModifiers.none);
  }

  final (specificKey, specificModifier) = switch (codePoint) {
    57441 => (const KeyCode.named(KeyCodeName.leftShift), KeyModifiers.shift),
    57442 => (const KeyCode.named(KeyCodeName.leftCtrl), KeyModifiers.ctrl),
    57443 => (const KeyCode.named(KeyCodeName.leftAlt), KeyModifiers.alt),
    57444 => (const KeyCode.named(KeyCodeName.leftSuper), KeyModifiers.superKey),
    57445 => (const KeyCode.named(KeyCodeName.leftHyper), KeyModifiers.hyper),
    57446 => (const KeyCode.named(KeyCodeName.leftMeta), KeyModifiers.meta),
    57447 => (const KeyCode.named(KeyCodeName.rightShift), KeyModifiers.shift),
    57448 => (const KeyCode.named(KeyCodeName.rightCtrl), KeyModifiers.ctrl),
    57449 => (const KeyCode.named(KeyCodeName.rightAlt), KeyModifiers.alt),
    57450 => (const KeyCode.named(KeyCodeName.rightSuper), KeyModifiers.superKey),
    57451 => (const KeyCode.named(KeyCodeName.rightHyper), KeyModifiers.hyper),
    57452 => (const KeyCode.named(KeyCodeName.rightMeta), KeyModifiers.meta),
    57453 => (const KeyCode.named(KeyCodeName.isoLevel3Shift), KeyModifiers.shift),
    57454 => (const KeyCode.named(KeyCodeName.isoLevel5Shift), KeyModifiers.shift),
    _ => (null, null),
  };

  if (specificKey != null) return (specificKey, specificModifier!);

  return (const KeyCode.named(KeyCodeName.none), KeyModifiers.none);
}
