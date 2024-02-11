import 'dart:convert';

import '../shared/color_util.dart';
import '../shared/int_extension.dart';
import '../shared/list_extension.dart';
import '../shared/string_extension.dart';
import '../termlib_base.dart';
import './events.dart';

bool _validSequence(List<int> sequence) {
  if (sequence[0] == 0x1b && sequence.length == 1) return true;
  // .[27u
  if (sequence.startsWith([0x1b, 0x5b, 0x32, 0x37, 0x75])) return true;
  // .[200~
  if (sequence.startsWith([0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E])) return true;
  // .]
  if (sequence.startsWith([0x1b, 0x5d])) return true;
  return false;
}

///
Event parseEvent(TermLib term, List<int> sequence) {
  if (sequence.isEmpty) return NoneEvent(sequence);
  if (sequence[0] == 0x1b && sequence.length == 1) return KeyEvent(const KeyCode(name: KeyCodeName.escape));
  // .[27u
  // if (sequence.startsWith([0x1b, 0x5b, 0x32, 0x37, 0x75])) {
  //  return KeyEvent(const KeyCode(name: KeyCodeName.escape));
  //}
  //return ParserErrorEvent(sequence);

  // If there are multiple ESC sequences, we parse the last one.
  // this is a ugly hack until we have the new event parser
  final moreEsc = sequence.lastIndexWhere((element) => element == 0x1b);
  if (moreEsc > 1 && !_validSequence(sequence)) {
    return parseEvent(term, sequence.sublist(moreEsc));
  }

  switch (sequence[0]) {
    case 0x1b:
      if (sequence.length == 1) return KeyEvent(const KeyCode(name: KeyCodeName.escape));
      switch (sequence[1]) {
        case 0x4F: // 'O'
          if (sequence.length == 2) return NoneEvent(sequence);
          switch (sequence[2]) {
            case 0x41: // 'A'
              return KeyEvent(const KeyCode(name: KeyCodeName.up));
            case 0x42: // 'B'
              return KeyEvent(const KeyCode(name: KeyCodeName.down));
            case 0x43: // 'C'
              return KeyEvent(const KeyCode(name: KeyCodeName.right));
            case 0x44: // 'D'
              return KeyEvent(const KeyCode(name: KeyCodeName.left));
            case 0x48: // 'H'
              return KeyEvent(const KeyCode(name: KeyCodeName.home));
            case 0x46: // 'F'
              return KeyEvent(const KeyCode(name: KeyCodeName.end));
            case 0x50: // 'P'
              return KeyEvent(const KeyCode(name: KeyCodeName.f1));
            case 0x51: // 'Q'
              return KeyEvent(const KeyCode(name: KeyCodeName.f2));
            case 0x52: // 'R'
              return KeyEvent(const KeyCode(name: KeyCodeName.f3));
            case 0x53: // 'S'
              return KeyEvent(const KeyCode(name: KeyCodeName.f4));
            default:
              return ParserErrorEvent(sequence);
          }
        case 0x5B: // '['
          return _parseCSI(term, sequence);
        case 0x5D: // ']'
          return _parseOSC(sequence);
        case 0x1B:
          return KeyEvent(const KeyCode(name: KeyCodeName.escape));
        case 0x7f:
          return KeyEvent(const KeyCode(name: KeyCodeName.backSpace));
        default:
          final ev = parseEvent(term, sequence.sublist(1));
          if (ev is KeyEvent) {
            var mod = ev.modifiers.add(KeyModifiers.alt);
            if (ev.code.char.isUpperCase()) mod = mod.add(KeyModifiers.shift);
            return KeyEvent(
              ev.code,
              modifiers: mod,
              eventType: ev.eventType,
              eventState: ev.eventState,
            );
          }
          return ev;
      }
    case 0x09: // '\t'
      return KeyEvent(const KeyCode(name: KeyCodeName.tab));
    case 0x0A: // '\n'
      if (term.rawMode) {
        return KeyEvent(const KeyCode(name: KeyCodeName.enter));
      }
    case 0x0d: // '\r'
      return KeyEvent(const KeyCode(name: KeyCodeName.enter));
    case 0x7F:
      return KeyEvent(const KeyCode(name: KeyCodeName.backSpace));
    case >= 0x01 && <= 0x1a:
      return KeyEvent(
        KeyCode(char: String.fromCharCode(sequence[0] - 0x01 + 0x61)),
        modifiers: const KeyModifiers(KeyModifiers.ctrl),
      );
    case >= 0x1C && <= 0x1F:
      return KeyEvent(
        KeyCode(char: String.fromCharCode(sequence[0] - 0x1C + 0x34)),
        modifiers: const KeyModifiers(KeyModifiers.ctrl),
      );
    case 0x00:
      return KeyEvent(const KeyCode(char: ' '), modifiers: const KeyModifiers(KeyModifiers.ctrl));
    default:
      final uni = utf8.decode(sequence, allowMalformed: true);
      var mod = KeyModifiers.empty();
      if (uni.isUpperCase()) mod = mod.add(KeyModifiers.shift);

      return KeyEvent(KeyCode(char: uni), modifiers: mod);
  }

  return NoneEvent(sequence);
}

Event _parseCSI(TermLib term, List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b]), ''); // ESC [
  if (sequence.length == 2) return NoneEvent(sequence);

  switch (sequence[2]) {
    case 0x41: // 'A'
      return KeyEvent(const KeyCode(name: KeyCodeName.up));
    case 0x42: // 'B'
      return KeyEvent(const KeyCode(name: KeyCodeName.down));
    case 0x43: // 'C'
      return KeyEvent(const KeyCode(name: KeyCodeName.right));
    case 0x44: // 'D'
      return KeyEvent(const KeyCode(name: KeyCodeName.left));
    case 0x48: // 'H'
      return KeyEvent(const KeyCode(name: KeyCodeName.home));
    case 0x46: // 'F'
      return KeyEvent(const KeyCode(name: KeyCodeName.end));
    case 0x5A: // 'Z'
      return KeyEvent(const KeyCode(name: KeyCodeName.backTab), modifiers: const KeyModifiers(KeyModifiers.shift));

    case 0x4D: // 'M'
      return _parseCSINormalMouse(sequence);
    case 0x3C: // '<'
      return _parseCSISgrMouse(sequence);
    case 0x49: // 'I'
      return const FocusEvent();
    case 0x4F: // 'O'
      return const FocusEvent(hasFocus: false);
    case 0x3B: // ';'
      return _parseCSIModifierKeyCode(sequence);
    case 0x50: // 'P'
      return KeyEvent(const KeyCode(name: KeyCodeName.f1));
    case 0x51: // 'Q'
      return KeyEvent(const KeyCode(name: KeyCodeName.f2));
    case 0x53: // 'S'
      return KeyEvent(const KeyCode(name: KeyCodeName.f4));
    case 0x3F: // '?'
      switch (sequence.last) {
        case 0x75: // 'u'
          return _parseCSIKeyboardEnhancementFlags(sequence);
        case 0x63: // 'c'
          return _parseCSIPrimaryDeviceAttributes(sequence);
      }
    case >= 0x30 && <= 0x39: // '0' - '9'
      if (sequence.length == 3) return NoneEvent(sequence);
      // The final byte of a CSI sequence can be in the range 64-126, so
      // let's keep reading anything else.
      final lastByte = sequence.last;
      if (lastByte < 0x40 && lastByte > 0x7E) {
        return NoneEvent(sequence);
      }
      // ESC[200~
      if (sequence.startsWith([0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E])) {
        return _parseCSIBracketedPaste(sequence);
      }
      switch (lastByte) {
        case 0x4D: // 'M'
          return NoneEvent(sequence);
        case 0x7E: // '~'
          return _parseCSISpecialKeyCode(sequence);
        case 0x75: // 'u'
          return _parseCSIuEncodedKeyCode(term, sequence);
        case 0x52: // 'R'
          return _parseCSICursorPosition(sequence);
        default:
          return _parseCSIModifierKeyCode(sequence);
      }

    default:
      return ParserErrorEvent(sequence);
  }

  return ParserErrorEvent(sequence);
}

Event _parseOSC(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5D]), ''); // ESC ]

  final buffer = sequence.sublist(2, sequence.length - 3).map(String.fromCharCode).join().split(';');

  if (buffer.length < 2) return ParserErrorEvent(sequence);
  if (!buffer[1].startsWith('rgb:')) return ParserErrorEvent(sequence);

  final clr = oscColor(buffer[1]);
  if (clr == null) return ParserErrorEvent(sequence);

  return ColorQueryEvent(clr.r, clr.g, clr.b);
}

//
///
///
/// https://sw.kovidgoyal.net/kitty/keyboard-protocol/#legacy-functional-keys
///
/// CSI key-code;modifier:1
Event _parseCSIModifierKeyCode(List<int> sequence) {
  final buffer = sequence.sublist(2, sequence.length - 1).map(String.fromCharCode).join().split(';');

  final keyMod = buffer.length == 1 ? buffer[0] : buffer[1];
  final (modifierMask, eventKind) = _modifierAndKindParse(keyMod);
  final modifier = modifierMask == null ? KeyModifiers.empty() : _parseModifier(modifierMask);
  final eventType = _parseEventKind(eventKind);
  final key = String.fromCharCode(sequence.last);

  final keyCode = switch (key) {
    'A' => KeyCodeName.up,
    'B' => KeyCodeName.down,
    'C' => KeyCodeName.right,
    'D' => KeyCodeName.left,
    'F' => KeyCodeName.end,
    'H' => KeyCodeName.home,
    'P' => KeyCodeName.f1,
    'Q' => KeyCodeName.f2,
    'R' => KeyCodeName.f3,
    'S' => KeyCodeName.f4,
    'Z' => KeyCodeName.backTab,
    _ => null
  };

  if (keyCode == null) return ParserErrorEvent(sequence);

  return KeyEvent(KeyCode(name: keyCode), modifiers: modifier, eventType: eventType);
}

Event _parseCSISpecialKeyCode(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b]), ''); // ESC [
  assert(sequence.endsWith([0x7E]), ''); // ~

  final buffer = sequence.sublist(2, sequence.length - 1).map(String.fromCharCode).join().split(';');

  final (modifierMask, eventKind) = buffer.length == 1 ? (null, null) : _modifierAndKindParse(buffer[1]);
  final modifier = modifierMask == null ? KeyModifiers.empty() : _parseModifier(modifierMask);
  final eventType = _parseEventKind(eventKind);
  final state = _parseModifiersToState(modifierMask);
  final keyCode = int.parse(buffer.first);

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
    _ => null
  };

  if (key == null) return ParserErrorEvent(sequence);

  return KeyEvent(
    KeyCode(name: key),
    modifiers: modifier,
    eventType: eventType,
    eventState: state,
  );
}

// Normal mouse encoding: ESC [ M CB Cx Cy (6 characters only).
Event _parseCSINormalMouse(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b, 0x4D]), ''); // ESC [ M

  if (sequence.length != 6) return ParserErrorEvent(sequence);

  final (kind, modifiers) = _parseCb(sequence[3].saturatingSub(32));
  // See http://www.xfree86.org/current/ctlseqs.html#Mouse%20Tracking
  final cx = sequence[4].saturatingSub(32);
  final cy = sequence[5].saturatingSub(32);

  return MouseEvent(cx, cy, kind, modifiers: modifiers);
}

Event _parseCSISgrMouse(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b, 0x3C]), ''); // ESC [ <

  // m M
  if (!sequence.endsWith([0x6D]) && !sequence.endsWith([0x4D])) {
    return ParserErrorEvent(sequence);
  }

  final buffer = sequence.sublist(3, sequence.length - 1).map(String.fromCharCode).join().split(';');
  if (buffer.length < 3) return ParserErrorEvent(sequence);

  final cb = int.parse(buffer[0]);
  final (kind, modifiers) = _parseCb(cb);

  final cx = int.parse(buffer[1]);
  final cy = int.parse(buffer[2]);

  // When button 3 in Cb is used to represent mouse release, you can't tell which button was
  // released. SGR mode solves this by having the sequence end with a lowercase m if it's a
  // button release and an uppercase M if it's a button press.

  var k = kind;

  // m
  if (sequence.last == 0x6D) {
    switch (kind) {
      case MouseEventKind(:final button, :final kind) when kind == MouseAction.down:
        k = MouseEventKind(button, MouseAction.up);
      default:
        k = kind;
    }
  }

  return MouseEvent(cx, cy, k, modifiers: modifiers);
}

Event _parseCSIKeyboardEnhancementFlags(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b, 0x3F]), ''); // ESC [ ?
  assert(sequence.endsWith([0x75]), ''); // u

  if (sequence.length < 5) return ParserErrorEvent(sequence);

  final bits = int.tryParse(sequence.sublist(3, sequence.length - 1).map(String.fromCharCode).join());
  if (bits == null) return ParserErrorEvent(sequence);
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

Event _parseCSIPrimaryDeviceAttributes(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b, 0x3F]), ''); // ESC [ ?
  assert(sequence.endsWith([0x63]), ''); // c

  // stub, not implemented
  return NoneEvent(sequence);
}

Event _parseCSIBracketedPaste(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]), ''); // ESC [ 2 0 0 ~

  if (!sequence.endsWith([0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7E])) {
    // ESC [ 2 0 1 ~
    return ParserErrorEvent(sequence);
  }

  final buffer = sequence.sublist(6, sequence.length - 6);
  final paste = utf8.decode(buffer, allowMalformed: true);
  return PasteEvent(paste);
}

Event _parseCSIuEncodedKeyCode(TermLib term, List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b]), ''); // ESC [
  assert(sequence.endsWith([0x75]), ''); // u

  // This function parses `CSI … u` sequences. These are sequences defined in either
  // the `CSI u` (a.k.a. "Fix Keyboard Input on Terminals - Please", https://www.leonerd.org.uk/hacks/fixterms/)
  // or Kitty Keyboard Protocol (https://sw.kovidgoyal.net/kitty/keyboard-protocol/) specifications.
  // This CSI sequence is a tuple of semicolon-separated numbers.
  final buffer = sequence.sublist(2, sequence.length - 1).map(String.fromCharCode).join().split(';');

  // In `CSI u`, this is parsed as:
  //
  //     CSI codePoint ; modifiers u
  //     codePoint: ASCII Dec value
  //
  // The Kitty Keyboard Protocol extends this with optional components that can be
  // enabled progressively. The full sequence is parsed as:
  //
  //     CSI unicode-key-code:alternate-key-codes ; modifiers:event-type ; text-as-codepoints u
  final codePoints = buffer.first.split(':');
  final codePoint = int.tryParse(codePoints.first);
  if (codePoint == null) return ParserErrorEvent(sequence);

  final (modifierMask, eventKind) = buffer.length == 1 ? (null, null) : _modifierAndKindParse(buffer[1]);
  var modifiers = modifierMask == null ? KeyModifiers.empty() : _parseModifier(modifierMask);
  final kind = _parseEventKind(eventKind);
  final stateFromModifiers = _parseModifiersToState(modifierMask);

  var (keyCode, stateFromKeyCode) = _translateFunctionalKeyCode(codePoint);

  if (keyCode == const KeyCode()) {
    final c = StringExtension.tryFromCharCode(codePoint);
    if (c == null) return ParserErrorEvent(sequence);

    keyCode = switch (codePoint) {
      0x1b => const KeyCode(name: KeyCodeName.escape),
      0xd => const KeyCode(name: KeyCodeName.enter),
      0xa => !term.rawMode ? const KeyCode(name: KeyCodeName.enter) : const KeyCode(),
      0x9 => modifiers.has(KeyModifiers.shift)
          ? const KeyCode(name: KeyCodeName.backTab)
          : const KeyCode(name: KeyCodeName.tab),
      0x7f => const KeyCode(name: KeyCodeName.backSpace),
      _ => KeyCode(char: String.fromCharCode(codePoint))
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
    _ => modifiers
  };

  if (modifiers.has(KeyModifiers.shift)) {
    if (codePoints.length > 1) {
      keyCode = KeyCode(char: String.fromCharCode(int.parse(codePoints[1])));
      modifiers.add(KeyModifiers.shift);
    }
  }

  return KeyEvent(
    keyCode,
    modifiers: modifiers,
    eventType: kind,
    eventState: stateFromKeyCode == KeyEventState.none() ? stateFromModifiers : stateFromKeyCode,
  );
}

/// Cb is the byte of a mouse input that contains the button being used, the key modifiers being
/// held and whether the mouse is dragging or not.
///
/// Bit layout of cb, from low to high:
///
/// - button number
/// - button number
/// - shift
/// - meta (alt)
/// - control
/// - mouse is dragging
/// - button number
/// - button number
(MouseEventKind, KeyModifiers) _parseCb(int cb) {
  final buttonNumber = (cb & 0x3) | ((cb & 0xC0) >> 4);
  final dragging = (cb & 0x20) == 0x20;

  final kind = switch ((buttonNumber, dragging)) {
    (0, false) => MouseEventKind.down(MouseButton.left),
    (1, false) => MouseEventKind.down(MouseButton.middle),
    (2, false) => MouseEventKind.down(MouseButton.right),
    (0, true) => MouseEventKind.drag(MouseButton.left),
    (1, true) => MouseEventKind.drag(MouseButton.middle),
    (2, true) => MouseEventKind.drag(MouseButton.right),
    (3, false) => MouseEventKind.up(MouseButton.left),
    (3, true) || (4, true) || (5, true) => MouseEventKind.moved(),
    (4, false) => MouseEventKind.wheelUp(),
    (5, false) => MouseEventKind.wheelDown(),
    (6, false) => MouseEventKind.wheelLeft(),
    (7, false) => MouseEventKind.wheelRight(),
    _ => null,
  };

  if (kind == null) return (MouseEventKind.none(), KeyModifiers.empty());

  var modifiers = KeyModifiers.empty();
  if ((cb & 0x4) == 0x4) modifiers = modifiers.add(KeyModifiers.shift);
  if ((cb & 0x8) == 0x8) modifiers = modifiers.add(KeyModifiers.alt);
  if ((cb & 0x10) == 0x10) modifiers = modifiers.add(KeyModifiers.ctrl);

  return (kind, modifiers);
}

// ESC [ Cy ; Cx R
//   Cy - cursor row number (starting from 1)
//   Cx - cursor column number (starting from 1)
Event _parseCSICursorPosition(List<int> sequence) {
  assert(sequence.startsWith([0x1b, 0x5b]), ''); // ESC [
  assert(sequence.endsWith([0x52]), ''); // R

  final buffer = sequence.sublist(2, sequence.length - 1).map(String.fromCharCode).join().split(';');
  final y = int.parse(buffer.first);
  final x = int.parse(buffer.last);

  return CursorPositionEvent(x, y);
}

(int?, int?) _modifierAndKindParse(String? modifierAndKey) {
  if (modifierAndKey == null) return (null, null);

  final split = modifierAndKey.split(':');
  final modifier = int.parse(split[0]);
  final kindCode = (split.length > 1) ? int.parse(split[1]) : null;

  return (modifier, kindCode ?? 1);
}

// Parse the modifier keys
KeyModifiers _parseModifier(int modifier) {
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
KeyEventType _parseEventKind(int? eventKindType) {
  return switch (eventKindType) {
    1 => KeyEventType.keyPress,
    2 => KeyEventType.keyRepeat,
    3 => KeyEventType.keyRelease,
    _ => KeyEventType.keyPress,
  };
}

KeyEventState _parseModifiersToState(int? modifierMask) {
  final mod = (modifierMask ?? 0).saturatingSub(1);
  var state = KeyEventState.none();
  if (mod & 64 != 0) state = state.add(KeyEventState.capsLock());
  if (mod & 128 != 0) state = state.add(KeyEventState.numLock());
  return state;
}

(KeyCode, KeyEventState) _translateFunctionalKeyCode(int codePoint) {
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
    _ => null
  };

  if (keyCode != null) return (keyCode, KeyEventState.none());

  return (const KeyCode(), const KeyEventState(0));
}
