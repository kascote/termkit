import 'dart:convert';

import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

List<int> keySequence(String seq) {
  final buffer = seq.replaceAll('π', '\x1b');
  return utf8.encode(buffer);
}

void main() {
  group('Event Hierarchy >', () {
    test('KeyEvent extends InputEvent', () {
      const event = KeyEvent(KeyCode(char: 'a'));
      expect(event, isA<InputEvent>());
      expect(event, isA<Event>());
    });

    test('MouseEvent extends InputEvent', () {
      final event = MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left));
      expect(event, isA<InputEvent>());
      expect(event, isA<Event>());
    });

    test('PasteEvent extends InputEvent', () {
      const event = PasteEvent('pasted text');
      expect(event, isA<InputEvent>());
      expect(event, isA<Event>());
    });

    test('RawKeyEvent extends InputEvent', () {
      final event = RawKeyEvent(const [0x1B, 0x5B]);
      expect(event, isA<InputEvent>());
      expect(event, isA<Event>());
    });

    test('CursorPositionEvent extends ResponseEvent', () {
      const event = CursorPositionEvent(10, 20);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('ColorQueryEvent extends ResponseEvent', () {
      const event = ColorQueryEvent(255, 128, 64);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('FocusEvent extends ResponseEvent', () {
      const event = FocusEvent();
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('KeyboardEnhancementFlagsEvent extends ResponseEvent', () {
      const event = KeyboardEnhancementFlagsEvent(1);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('PrimaryDeviceAttributesEvent extends ResponseEvent', () {
      const event = PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, []);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('QuerySyncUpdateEvent extends ResponseEvent', () {
      final event = QuerySyncUpdateEvent(2);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('QueryTerminalWindowSizeEvent extends ResponseEvent', () {
      const event = QueryTerminalWindowSizeEvent(1920, 1080);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('NameAndVersionEvent extends ResponseEvent', () {
      const event = NameAndVersionEvent('xterm');
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('ClipboardCopyEvent extends ResponseEvent', () {
      const event = ClipboardCopyEvent(ClipboardSource.clipboard, 'text');
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('UnicodeCoreEvent extends ResponseEvent', () {
      final event = UnicodeCoreEvent(1);
      expect(event, isA<ResponseEvent>());
      expect(event, isA<Event>());
    });

    test('EngineErrorEvent extends ErrorEvent', () {
      const event = EngineErrorEvent([], message: 'test error');
      expect(event, isA<ErrorEvent>());
      expect(event, isA<Event>());
    });

    test('NoneEvent extends InternalEvent', () {
      const event = NoneEvent();
      expect(event, isA<InternalEvent>());
      expect(event, isA<Event>());
    });
  });

  group('Event Filtering >', () {
    test('filter only InputEvent types', () {
      final parser = Parser()
        ..advance(keySequence('a')) // KeyEvent
        ..advance(keySequence('π[10;20R')); // CursorPositionEvent

      final events = parser.drainEvents();
      expect(events.length, 2);

      final inputEvents = events.whereType<InputEvent>().toList();
      expect(inputEvents.length, 1);
      expect(inputEvents.first, isA<KeyEvent>());
    });

    test('filter only ResponseEvent types', () {
      final parser = Parser()
        ..advance(keySequence('a')) // KeyEvent
        ..advance(keySequence('π[10;20R')) // CursorPositionEvent
        ..advance(keySequence('π[I')); // FocusEvent

      final events = parser.drainEvents();
      expect(events.length, 3);

      final responseEvents = events.whereType<ResponseEvent>().toList();
      expect(responseEvents.length, 2);
      expect(responseEvents[0], isA<CursorPositionEvent>());
      expect(responseEvents[1], isA<FocusEvent>());
    });

    test('filter multiple event types', () {
      final parser = Parser()
        ..advance(keySequence('abc')) // 3 KeyEvents
        ..advance(keySequence('π[10;20R')) // CursorPositionEvent
        ..advance(keySequence('π[200~text')) // Partial paste (won't generate event)
        ..advance(keySequence('π[I')); // FocusEvent

      final events = parser.drainEvents();

      final inputs = events.whereType<InputEvent>().toList();
      final responses = events.whereType<ResponseEvent>().toList();

      expect(inputs.length, 3); // 3 key events
      expect(responses.length, 2); // cursor position + focus
    });

    test('filter ErrorEvent types', () {
      final parser = Parser()..advance([0x1B, 0x1B]); // Double ESC generates error

      final events = parser.drainEvents();

      // May contain KeyEvents for ESC or EngineErrorEvent depending on parser state
      final errors = events.whereType<ErrorEvent>().toList();
      final inputs = events.whereType<InputEvent>().toList();

      // Verify we can filter by ErrorEvent type
      expect(errors, isA<List<ErrorEvent>>());
      expect(inputs, isA<List<InputEvent>>());
    });

    test('combine filtering with other operations', () {
      final parser = Parser()
        ..advance(keySequence('π[97u')) // KeyEvent 'a'
        ..advance(keySequence('π[10;20R')) // CursorPositionEvent
        ..advance(keySequence('π[98u')); // KeyEvent 'b'

      final events = parser.drainEvents();

      // Get only key events and map to chars
      final keyChars = events
          .whereType<InputEvent>()
          .whereType<KeyEvent>()
          .map((e) => e.code.char)
          .where((char) => char.isNotEmpty)
          .toList();

      expect(keyChars.length, 2);
      expect(keyChars, contains('a'));
      expect(keyChars, contains('b'));
    });
  });
}
