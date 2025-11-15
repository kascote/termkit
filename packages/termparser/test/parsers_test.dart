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
