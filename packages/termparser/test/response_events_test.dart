import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('CursorPositionEvent >', () {
    test('constructor', () {
      const event = CursorPositionEvent(10, 20);
      expect(event.x, 10);
      expect(event.y, 20);
    });

    test('equality - identical events', () {
      const event1 = CursorPositionEvent(5, 10);
      const event2 = CursorPositionEvent(5, 10);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different x', () {
      const event1 = CursorPositionEvent(5, 10);
      const event2 = CursorPositionEvent(6, 10);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different y', () {
      const event1 = CursorPositionEvent(5, 10);
      const event2 = CursorPositionEvent(5, 11);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = CursorPositionEvent(15, 25);
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('KeyboardEnhancementFlagsEvent >', () {
    test('constructor with default mode', () {
      const event = KeyboardEnhancementFlagsEvent(1);
      expect(event.flags, 1);
      expect(event.mode, 1);
    });

    test('constructor with mode', () {
      const event = KeyboardEnhancementFlagsEvent(7, 2);
      expect(event.flags, 7);
      expect(event.mode, 2);
    });

    test('empty factory', () {
      final event = KeyboardEnhancementFlagsEvent.empty();
      expect(event.flags, 0);
      expect(event.mode, 1);
    });

    test('add flag', () {
      const initial = KeyboardEnhancementFlagsEvent(1);
      final updated = initial.add(2);

      expect(updated.flags, 3); // 1 | 2 = 3
      expect(initial.flags, 1); // original unchanged
    });

    test('has flag', () {
      const event = KeyboardEnhancementFlagsEvent(3); // flags: 1 | 2

      expect(event.has(1), isTrue);
      expect(event.has(2), isTrue);
      expect(event.has(4), isFalse);
    });

    test('equality - identical events', () {
      const event1 = KeyboardEnhancementFlagsEvent(7, 2);
      const event2 = KeyboardEnhancementFlagsEvent(7, 2);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different flags', () {
      const event1 = KeyboardEnhancementFlagsEvent(1);
      const event2 = KeyboardEnhancementFlagsEvent(2);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different mode', () {
      const event1 = KeyboardEnhancementFlagsEvent(1);
      const event2 = KeyboardEnhancementFlagsEvent(1, 2);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = KeyboardEnhancementFlagsEvent(15, 3);
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('ColorQueryEvent >', () {
    test('constructor', () {
      const event = ColorQueryEvent(255, 128, 64);
      expect(event.r, 255);
      expect(event.g, 128);
      expect(event.b, 64);
    });

    test('equality - identical events', () {
      const event1 = ColorQueryEvent(100, 150, 200);
      const event2 = ColorQueryEvent(100, 150, 200);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different r', () {
      const event1 = ColorQueryEvent(100, 150, 200);
      const event2 = ColorQueryEvent(101, 150, 200);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different g', () {
      const event1 = ColorQueryEvent(100, 150, 200);
      const event2 = ColorQueryEvent(100, 151, 200);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different b', () {
      const event1 = ColorQueryEvent(100, 150, 200);
      const event2 = ColorQueryEvent(100, 150, 201);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = ColorQueryEvent(10, 20, 30);
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('PrimaryDeviceAttributesEvent >', () {
    test('constructor', () {
      const event = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt500,
        [DeviceAttributeParams.sixelGraphics, DeviceAttributeParams.ansiColor],
      );
      expect(event.type, DeviceAttributeType.vt500);
      expect(event.params.length, 2);
      expect(event.params, contains(DeviceAttributeParams.sixelGraphics));
      expect(event.params, contains(DeviceAttributeParams.ansiColor));
    });

    test('equality - identical events', () {
      const event1 = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt220,
        [DeviceAttributeParams.columns132],
      );
      const event2 = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt220,
        [DeviceAttributeParams.columns132],
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different type', () {
      const event1 = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt220,
        [DeviceAttributeParams.columns132],
      );
      const event2 = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt320,
        [DeviceAttributeParams.columns132],
      );

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different params', () {
      const event1 = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt220,
        [DeviceAttributeParams.columns132],
      );
      const event2 = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt220,
        [DeviceAttributeParams.printer],
      );

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = PrimaryDeviceAttributesEvent(
        DeviceAttributeType.vt500,
        [DeviceAttributeParams.sixelGraphics],
      );
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('NameAndVersionEvent >', () {
    test('constructor', () {
      const event = NameAndVersionEvent('xterm-256color');
      expect(event.value, 'xterm-256color');
    });

    test('equality - identical events', () {
      const event1 = NameAndVersionEvent('iTerm2');
      const event2 = NameAndVersionEvent('iTerm2');

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different value', () {
      const event1 = NameAndVersionEvent('xterm');
      const event2 = NameAndVersionEvent('iTerm2');

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = NameAndVersionEvent('terminal-v1.0');
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('QuerySyncUpdateEvent >', () {
    test('constructor with enabled status', () {
      final event = QuerySyncUpdateEvent(1);
      expect(event.code, 1);
      expect(event.status, DECRPMStatus.enabled);
    });

    test('constructor with disabled status', () {
      final event = QuerySyncUpdateEvent(2);
      expect(event.code, 2);
      expect(event.status, DECRPMStatus.disabled);
    });

    test('constructor with not recognized status', () {
      final event = QuerySyncUpdateEvent(0);
      expect(event.code, 0);
      expect(event.status, DECRPMStatus.notRecognized);
    });

    test('constructor with unknown code defaults to not recognized', () {
      final event = QuerySyncUpdateEvent(999);
      expect(event.code, 999);
      expect(event.status, DECRPMStatus.notRecognized);
    });

    test('equality - identical events', () {
      final event1 = QuerySyncUpdateEvent(1);
      final event2 = QuerySyncUpdateEvent(1);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different code', () {
      final event1 = QuerySyncUpdateEvent(1);
      final event2 = QuerySyncUpdateEvent(2);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      final event = QuerySyncUpdateEvent(3);
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('QueryTerminalWindowSizeEvent >', () {
    test('constructor', () {
      const event = QueryTerminalWindowSizeEvent(1920, 1080);
      expect(event.width, 1920);
      expect(event.height, 1080);
    });

    test('equality - identical events', () {
      const event1 = QueryTerminalWindowSizeEvent(800, 600);
      const event2 = QueryTerminalWindowSizeEvent(800, 600);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different width', () {
      const event1 = QueryTerminalWindowSizeEvent(800, 600);
      const event2 = QueryTerminalWindowSizeEvent(1024, 600);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different height', () {
      const event1 = QueryTerminalWindowSizeEvent(800, 600);
      const event2 = QueryTerminalWindowSizeEvent(800, 768);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = QueryTerminalWindowSizeEvent(1280, 720);
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('ClipboardCopyEvent >', () {
    test('constructor', () {
      const event = ClipboardCopyEvent(ClipboardSource.clipboard, 'hello');
      expect(event.source, ClipboardSource.clipboard);
      expect(event.text, 'hello');
    });

    test('equality - identical events', () {
      const event1 = ClipboardCopyEvent(ClipboardSource.primary, 'test');
      const event2 = ClipboardCopyEvent(ClipboardSource.primary, 'test');

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different source', () {
      const event1 = ClipboardCopyEvent(ClipboardSource.clipboard, 'test');
      const event2 = ClipboardCopyEvent(ClipboardSource.primary, 'test');

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different text', () {
      const event1 = ClipboardCopyEvent(ClipboardSource.clipboard, 'hello');
      const event2 = ClipboardCopyEvent(ClipboardSource.clipboard, 'world');

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      const event = ClipboardCopyEvent(ClipboardSource.selection, 'data');
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('ColorSchemeEvent >', () {
    test('constructor with dark mode', () {
      final event = ColorSchemeEvent(1);
      expect(event.code, 1);
      expect(event.mode, ColorSchemeMode.dark);
    });

    test('constructor with light mode', () {
      final event = ColorSchemeEvent(2);
      expect(event.code, 2);
      expect(event.mode, ColorSchemeMode.light);
    });

    test('constructor with unknown mode', () {
      final event = ColorSchemeEvent(0);
      expect(event.code, 0);
      expect(event.mode, ColorSchemeMode.unknown);
    });

    test('constructor with invalid code defaults to unknown', () {
      final event = ColorSchemeEvent(999);
      expect(event.code, 999);
      expect(event.mode, ColorSchemeMode.unknown);
    });

    test('equality - identical events', () {
      final event1 = ColorSchemeEvent(1);
      final event2 = ColorSchemeEvent(1);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different code', () {
      final event1 = ColorSchemeEvent(1);
      final event2 = ColorSchemeEvent(2);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      final event = ColorSchemeEvent(1);
      expect(event.hashCode, equals(event.hashCode));
    });
  });

  group('UnicodeCoreEvent >', () {
    test('constructor with enabled status', () {
      final event = UnicodeCoreEvent(1);
      expect(event.code, 1);
      expect(event.status, DECRPMStatus.enabled);
    });

    test('constructor with disabled status', () {
      final event = UnicodeCoreEvent(2);
      expect(event.code, 2);
      expect(event.status, DECRPMStatus.disabled);
    });

    test('constructor with not recognized status', () {
      final event = UnicodeCoreEvent(0);
      expect(event.code, 0);
      expect(event.status, DECRPMStatus.notRecognized);
    });

    test('constructor with unknown code defaults to not recognized', () {
      final event = UnicodeCoreEvent(999);
      expect(event.code, 999);
      expect(event.status, DECRPMStatus.notRecognized);
    });

    test('equality - identical events', () {
      final event1 = UnicodeCoreEvent(1);
      final event2 = UnicodeCoreEvent(1);

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different code', () {
      final event1 = UnicodeCoreEvent(1);
      final event2 = UnicodeCoreEvent(2);

      expect(event1, isNot(equals(event2)));
    });

    test('hashCode - consistent', () {
      final event = UnicodeCoreEvent(3);
      expect(event.hashCode, equals(event.hashCode));
    });
  });
}
