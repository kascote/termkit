import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('RawKeyEvent >', () {
    test('constructor', () {
      final event = RawKeyEvent(const [0x1B, 0x5B]);
      expect(event.sequence, [0x1B, 0x5B]);
    });

    test('constructor creates copy of list', () {
      final original = [0x1B, 0x5B];
      final event = RawKeyEvent(original);

      // Modify original - should not affect event
      original[0] = 0x00;
      expect(event.sequence, [0x1B, 0x5B]);
    });

    test('equality - identical events', () {
      final event1 = RawKeyEvent(const [0x1B, 0x5B]);
      final event2 = RawKeyEvent(const [0x1B, 0x5B]);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different sequences', () {
      final event1 = RawKeyEvent(const [0x1B, 0x5B]);
      final event2 = RawKeyEvent(const [0x1B, 0x4F]);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different length', () {
      final event1 = RawKeyEvent(const [0x1B]);
      final event2 = RawKeyEvent(const [0x1B, 0x5B]);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      final event = RawKeyEvent(const [0x1B, 0x5B, 0x41]);
      expect(event.hashCode, equals(event.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      final event1 = RawKeyEvent(const [0x41, 0x42]);
      final event2 = RawKeyEvent(const [0x41, 0x42]);

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('is InputEvent', () {
      final event = RawKeyEvent(const [0x1B]);
      expect(event, isA<InputEvent>());
    });
  });

  group('FocusEvent >', () {
    test('constructor with default hasFocus', () {
      const event = FocusEvent();
      expect(event.hasFocus, isTrue);
    });

    test('constructor with hasFocus true', () {
      const event = FocusEvent();
      expect(event.hasFocus, isTrue);
    });

    test('constructor with hasFocus false', () {
      const event = FocusEvent(hasFocus: false);
      expect(event.hasFocus, isFalse);
    });

    test('equality - identical events', () {
      const event1 = FocusEvent();
      const event2 = FocusEvent();

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different hasFocus', () {
      const event1 = FocusEvent();
      const event2 = FocusEvent(hasFocus: false);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = FocusEvent();
      expect(event.hashCode, equals(event.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      const event1 = FocusEvent(hasFocus: false);
      const event2 = FocusEvent(hasFocus: false);

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('is ResponseEvent', () {
      const event = FocusEvent();
      expect(event, isA<ResponseEvent>());
    });
  });

  group('NoneEvent >', () {
    test('constructor', () {
      const event = NoneEvent();
      expect(event, isNotNull);
    });

    test('equality - identical events', () {
      const event1 = NoneEvent();
      const event2 = NoneEvent();

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('hashCode - consistent', () {
      const event = NoneEvent();
      expect(event.hashCode, equals(event.hashCode));
    });

    test('hashCode - all NoneEvent instances have same hashCode', () {
      const event1 = NoneEvent();
      const event2 = NoneEvent();

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('is InternalEvent', () {
      const event = NoneEvent();
      expect(event, isA<InternalEvent>());
    });
  });

  group('PasteEvent >', () {
    test('constructor', () {
      const event = PasteEvent('hello world');
      expect(event.text, 'hello world');
    });

    test('constructor with empty text', () {
      const event = PasteEvent('');
      expect(event.text, isEmpty);
    });

    test('equality - identical events', () {
      const event1 = PasteEvent('test');
      const event2 = PasteEvent('test');

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different text', () {
      const event1 = PasteEvent('hello');
      const event2 = PasteEvent('world');

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = PasteEvent('some text');
      expect(event.hashCode, equals(event.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      const event1 = PasteEvent('identical');
      const event2 = PasteEvent('identical');

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('is InputEvent', () {
      const event = PasteEvent('text');
      expect(event, isA<InputEvent>());
    });
  });
}
