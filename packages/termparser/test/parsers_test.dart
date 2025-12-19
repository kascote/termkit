import 'dart:convert';

import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Helper to convert test sequences to byte arrays.
/// Use π (pi) to represent ESC (0x1B) for readability.
List<int> keySequence(String seq) {
  final buffer = seq.replaceAll('π', '\x1b');
  return utf8.encode(buffer);
}

void main() {
  group('char_parser >', () {
    test('escO with unknown character returns none', () {
      final parser = Parser()..advance(keySequence('πOX')); // X is not P/Q/R/S
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.code, const KeyCode.named(KeyCodeName.none));
    });

    test('escO with P/Q/R/S return F1-F4', () {
      var parser = Parser()..advance(keySequence('πOP'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f1));

      parser = Parser()..advance(keySequence('πOQ'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f2));

      parser = Parser()..advance(keySequence('πOR'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f3));

      parser = Parser()..advance(keySequence('πOS'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f4));
    });
  });

  group('parser_base >', () {
    test('ctrl characters 0x01-0x1A', () {
      // Ctrl+A (0x01) -> 'a'
      final parser1 = Parser()..advance([0x01]);
      expect(parser1.hasEvents, true);
      final event1 = parser1.nextEvent()! as KeyEvent;
      expect(event1.code, const KeyCode.char('a'));
      expect(event1.modifiers.value, KeyModifiers.ctrl);

      // Ctrl+C (0x03) -> 'c'
      final parser2 = Parser()..advance([0x03]);
      final event2 = parser2.nextEvent()! as KeyEvent;
      expect(event2.code, const KeyCode.char('c'));
      expect(event2.modifiers.value, KeyModifiers.ctrl);

      // Ctrl+Z (0x1A) -> 'z'
      final parser3 = Parser()..advance([0x1A]);
      final event3 = parser3.nextEvent()! as KeyEvent;
      expect(event3.code, const KeyCode.char('z'));
      expect(event3.modifiers.value, KeyModifiers.ctrl);
    });

    test('ctrl characters 0x1C-0x1F', () {
      // Ctrl+\ (0x1C) -> '4'
      final parser1 = Parser()..advance([0x1C]);
      expect(parser1.hasEvents, true);
      final event1 = parser1.nextEvent()! as KeyEvent;
      expect(event1.code, const KeyCode.char('4'));
      expect(event1.modifiers.value, KeyModifiers.ctrl);

      // Ctrl+] (0x1D) -> '5'
      final parser2 = Parser()..advance([0x1D]);
      final event2 = parser2.nextEvent()! as KeyEvent;
      expect(event2.code, const KeyCode.char('5'));
      expect(event2.modifiers.value, KeyModifiers.ctrl);

      // Ctrl+^ (0x1E) -> '6'
      final parser3 = Parser()..advance([0x1E]);
      final event3 = parser3.nextEvent()! as KeyEvent;
      expect(event3.code, const KeyCode.char('6'));
      expect(event3.modifiers.value, KeyModifiers.ctrl);

      // Ctrl+_ (0x1F) -> '7'
      final parser4 = Parser()..advance([0x1F]);
      final event4 = parser4.nextEvent()! as KeyEvent;
      expect(event4.code, const KeyCode.char('7'));
      expect(event4.modifiers.value, KeyModifiers.ctrl);
    });

    test('backspace with shift modifier - 127', () {
      final parser = Parser()..advance([0x7f]);
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.code, const KeyCode.named(KeyCodeName.backSpace));
      expect(event.modifiers, KeyModifiers.none);
    });
  });

  group('osc_parser >', () {
    test('clipboard with primary source', () {
      final parser = Parser()..advance(keySequence(r'π]52;p;SGVsbG8=π\\'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as ClipboardCopyEvent;
      expect(event.source, ClipboardSource.primary);
      expect(event.text, 'Hello');
    });

    test('clipboard with secondary source', () {
      final parser = Parser()..advance(keySequence(r'π]52;q;VGVzdA==π\\'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as ClipboardCopyEvent;
      expect(event.source, ClipboardSource.secondary);
      expect(event.text, 'Test');
    });

    test('clipboard with selection source', () {
      final parser = Parser()..advance(keySequence(r'π]52;s;SGk=π\\'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as ClipboardCopyEvent;
      expect(event.source, ClipboardSource.selection);
      expect(event.text, 'Hi');
    });

    test('clipboard with cut buffer sources (0-7)', () {
      for (var i = 0; i <= 7; i++) {
        final parser = Parser()..advance(keySequence('π]52;$i;YQ==π\\\\'));
        expect(parser.hasEvents, true);
        final event = parser.nextEvent()! as ClipboardCopyEvent;
        expect(event.source, ClipboardSource.cutBuffer);
        expect(event.text, 'a');
      }
    });
  });

  group('csi_parser >', () {
    test('window size query - CSI 4;height;width t', () {
      final parser = Parser()..advance(keySequence('π[4;1080;1920t'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as QueryTerminalWindowSizeEvent;
      expect(event.width, 1080);
      expect(event.height, 1920);
    });

    test(r'unicode core event - CSI ?2027;1$y', () {
      final parser = Parser()..advance(keySequence(r'π[?2027;1$y'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as UnicodeCoreEvent;
      expect(event.code, 1);
      expect(event.status, DECRPMStatus.enabled);
    });

    test('tab with shift modifier - CSI 9;2u', () {
      final parser = Parser()..advance(keySequence('π[9;2u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.code, const KeyCode.named(KeyCodeName.tab));
      expect(event.modifiers, KeyModifiers.shift);
    });

    test('tab with shift modifier - CSI Z', () {
      final parser = Parser()..advance(keySequence('π[Z'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.code, const KeyCode.named(KeyCodeName.tab));
      expect(event.modifiers, KeyModifiers.shift);
    });

    test('backspace with shift modifier - CSI 127 u', () {
      final parser = Parser()..advance(keySequence('π[127u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.code, const KeyCode.named(KeyCodeName.backSpace));
      expect(event.modifiers, KeyModifiers.none);
    });

    test('function keys F1-F20 via CSI~', () {
      // F1 = 11~
      var parser = Parser()..advance(keySequence('π[11~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f1));

      // F5 = 15~
      parser = Parser()..advance(keySequence('π[15~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f5));

      // F6 = 17~
      parser = Parser()..advance(keySequence('π[17~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f6));

      // F11 = 23~
      parser = Parser()..advance(keySequence('π[23~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f11));

      // F12 = 24~
      parser = Parser()..advance(keySequence('π[24~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f12));

      // F13 = 25~
      parser = Parser()..advance(keySequence('π[25~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f13));

      // F14 = 26~
      parser = Parser()..advance(keySequence('π[26~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f14));

      // F15 = 28~
      parser = Parser()..advance(keySequence('π[28~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f15));

      // F16 = 29~
      parser = Parser()..advance(keySequence('π[29~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f16));

      // F17 = 31~
      parser = Parser()..advance(keySequence('π[31~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f17));

      // F18 = 32~
      parser = Parser()..advance(keySequence('π[32~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f18));

      // F19 = 33~
      parser = Parser()..advance(keySequence('π[33~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f19));

      // F20 = 34~
      parser = Parser()..advance(keySequence('π[34~'));
      expect((parser.nextEvent()! as KeyEvent).code, const KeyCode.named(KeyCodeName.f20));
    });

    test('device attributes - VT100 with advanced video', () {
      final parser = Parser()..advance(keySequence('π[?1;2c'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as PrimaryDeviceAttributesEvent;
      expect(event.type, DeviceAttributeType.vt100WithAdvancedVideoOption);
    });

    test('device attributes - unknown type', () {
      final parser = Parser()..advance(keySequence('π[?99c'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as PrimaryDeviceAttributesEvent;
      expect(event.type, DeviceAttributeType.unknown);
    });

    test('device attributes - unknown param code', () {
      final parser = Parser()..advance(keySequence('π[?62;9999c'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as PrimaryDeviceAttributesEvent;
      expect(event.type, DeviceAttributeType.vt220);
      expect(event.params, isEmpty); // Unknown param should be filtered out
    });
  });

  group('key_parser >', () {
    test('keyboard enhancement flags - reportEventTypes', () {
      // Test flag 0x2 (reportEventTypes)
      final parser = Parser()..advance(keySequence('π[?2u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyboardEnhancementFlagsEvent;
      expect(event.has(KeyboardEnhancementFlagsEvent.reportEventTypes), isTrue);
    });

    test('keyboard enhancement flags - reportAlternateKeys', () {
      // Test flag 0x4 (reportAlternateKeys)
      final parser = Parser()..advance(keySequence('π[?4u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyboardEnhancementFlagsEvent;
      expect(event.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys), isTrue);
    });

    test('keyboard enhancement flags - reportAllKeysAsEscapeCodes', () {
      // Test flag 0x8 (reportAllKeysAsEscapeCodes)
      final parser = Parser()..advance(keySequence('π[?8u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyboardEnhancementFlagsEvent;
      expect(event.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes), isTrue);
    });

    test('keyboard enhancement flags - multiple flags combined', () {
      // Test multiple flags: 1 | 2 | 4 | 8 = 15
      final parser = Parser()..advance(keySequence('π[?15u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyboardEnhancementFlagsEvent;
      expect(event.has(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes), isTrue);
      expect(event.has(KeyboardEnhancementFlagsEvent.reportEventTypes), isTrue);
      expect(event.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys), isTrue);
      expect(event.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes), isTrue);
    });
  });
}
