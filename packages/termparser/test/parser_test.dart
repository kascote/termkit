import 'dart:convert';

import 'package:termparser/src/sequences.dart';
import 'package:termparser/src/sequences/key_sequence.dart';
import 'package:termparser/src/sequences/mouse_data.dart';
import 'package:termparser/termparser.dart';
import 'package:test/test.dart';

List<int> keySequence(String seq) {
  final buffer = seq.replaceAll('π', '\x1b');
  return utf8.encode(buffer);
}

void main() {
  group('Parser >', () {
    test('char', () {
      final parser = Parser()..advance([0x61]);
      expect(parser.moveNext(), true);
    });

    test('esc sequence', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x61]);
      expect(parser.moveNext(), true);
    });

    test('esc sequence with uppercase O', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x4F]);
      expect(parser.moveNext(), false);
    });

    test('esc sequence with uppercase O followed by a char', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x4F], more: true); // O
      expect(parser.moveNext(), false);
      parser.advance([0x50]); // P
      expect(parser.moveNext(), true);
      expect(parser.moveNext(), false);
    });
  });

  group('CSI > ', () {
    test('sequence', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x5B], more: true); // [
      expect(parser.moveNext(), false);
      parser.advance([0x44]); // D
      expect(parser.moveNext(), true);
    });

    test('ESC [1;3:2H', () {
      final parser = Parser()..advance([0x1B, 0x5B, 0x31, 0x3b, 0x32, 0x3a, 0x33, 0x48]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        const KeySequence(
          KeyCode(name: KeyCodeName.home),
          modifiers: KeyModifiers(KeyModifiers.shift),
          eventType: KeyEventType.keyRelease,
        ),
      );
    });

    test('ESC [H', () {
      final parser = Parser()..advance([0x1B, 0x5B, 0x48]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        const KeySequence(KeyCode(name: KeyCodeName.home)),
      );
    });

    test('ESC [< 35 ; 86 ; 18 M', () {
      final parser = Parser()..advance(keySequence('π[<35;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseSequence(86, 18, MouseButtonEvent.moved(MouseButton.none)),
      );
    });

    test('ESC [< 32 ; 86 ; 18 M (drag)', () {
      final parser = Parser()..advance(keySequence('π[<32;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseSequence(86, 18, MouseButtonEvent.moved(MouseButton.left)),
      );
    });

    test('ESC [< 24 ; 86 ; 18 M', () {
      final parser = Parser()..advance(keySequence('π[<24;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseSequence(
          86,
          18,
          MouseButtonEvent.down(MouseButton.left),
          modifiers: const KeyModifiers(KeyModifiers.ctrl | KeyModifiers.alt),
        ),
      );
    });

    test('ESC [I', () {
      final parser = Parser()..advance(keySequence('π[I'));
      expect(parser.moveNext(), true);
      expect(parser.current, const FocusSequence());
    });

    test('ESC [O', () {
      final parser = Parser()..advance(keySequence('π[O'));
      expect(parser.moveNext(), true);
      expect(parser.current, const FocusSequence(hasFocus: false));
    });

    test('ESC [ ? 1 u', () {
      final parser = Parser()..advance(keySequence('π[?1u'));
      expect(parser.moveNext(), true);
      expect(parser.current, equals(const KeyboardEnhancementFlags(KeyboardEnhancementFlags.disambiguateEscapeCodes)));
    });

    test('ESC [ 97 u', () {
      final parser = Parser()..advance(keySequence('π[97u'));
      expect(parser.moveNext(), true);
      expect(parser.current, equals(const KeyboardEnhancementFlags(KeyboardEnhancementFlags.disambiguateEscapeCodes)));
    });

    test('ESC [ 97 : 65 ; 2 u', () {
      final parser = Parser()..advance(keySequence('π[97:65;2u'));
      expect(parser.moveNext(), true);
      expect(parser.current, equals(const KeyboardEnhancementFlags(KeyboardEnhancementFlags.disambiguateEscapeCodes)));
    });
  });
}
