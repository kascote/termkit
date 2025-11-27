import 'dart:async';

import 'package:termlib/src/event_queue.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('EventQueue >', () {
    test('new queue should be empty', () {
      final queue = EventQueue();
      expect(queue.length, 0);
      expect(queue.dequeue<Event>(), isNull);
    });

    test('enqueue should add events', () {
      final queue = EventQueue()..enqueue(KeyEvent.fromString('enter'));
      expect(queue.length, 1);
    });

    test('dequeue should return null when queue is empty', () {
      final queue = EventQueue();
      expect(queue.dequeue<Event>(), isNull);
      expect(queue.dequeue<KeyEvent>(), isNull);
      expect(queue.dequeue<MouseEvent>(), isNull);
    });

    test('dequeue should return and remove first matching event', () {
      final queue = EventQueue();
      final event1 = KeyEvent.fromString('enter');
      final event2 = KeyEvent.fromString('escape');

      queue
        ..enqueue(event1)
        ..enqueue(event2);

      expect(queue.length, 2);
      final dequeued = queue.dequeue<KeyEvent>();
      expect(dequeued, event1);
      expect(queue.length, 1);
    });

    test('dequeue with Event type should return first event regardless of subtype', () {
      final queue = EventQueue();
      final keyEvent = KeyEvent.fromString('enter');
      const mouseEvent = MouseEvent(
        10,
        20,
        MouseButton(MouseButtonKind.left, MouseButtonAction.down),
      );

      queue
        ..enqueue(mouseEvent)
        ..enqueue(keyEvent);

      expect(queue.length, 2);
      final dequeued = queue.dequeue<Event>();
      expect(dequeued, mouseEvent);
      expect(queue.length, 1);
    });

    test('dequeue should skip non-matching types', () {
      final queue = EventQueue();
      const mouseEvent = MouseEvent(
        10,
        20,
        MouseButton(MouseButtonKind.left, MouseButtonAction.down),
      );
      final keyEvent = KeyEvent.fromString('enter');

      queue
        ..enqueue(mouseEvent)
        ..enqueue(keyEvent);

      expect(queue.length, 2);
      final dequeued = queue.dequeue<KeyEvent>();
      expect(dequeued, keyEvent);
      expect(queue.length, 1);

      final remaining = queue.dequeue<Event>();
      expect(remaining, mouseEvent);
      expect(queue.length, 0);
    });

    test('dequeue should return null if no matching type found', () {
      final queue = EventQueue()
        ..enqueue(
          const MouseEvent(
            0,
            0,
            MouseButton(MouseButtonKind.left, MouseButtonAction.down),
          ),
        );

      expect(queue.dequeue<KeyEvent>(), isNull);
      expect(queue.length, 1);
    });

    test('hasEvent should return false for empty queue', () {
      final queue = EventQueue();
      expect(queue.hasEvent<Event>(), isFalse);
      expect(queue.hasEvent<KeyEvent>(), isFalse);
    });

    test('hasEvent should return true if matching event exists', () {
      final queue = EventQueue()..enqueue(KeyEvent.fromString('enter'));

      expect(queue.hasEvent<Event>(), isTrue);
      expect(queue.hasEvent<KeyEvent>(), isTrue);
      expect(queue.hasEvent<MouseEvent>(), isFalse);
    });

    test('hasEvent should not remove events', () {
      final queue = EventQueue()..enqueue(KeyEvent.fromString('enter'));

      expect(queue.hasEvent<KeyEvent>(), isTrue);
      expect(queue.length, 1);
      expect(queue.hasEvent<KeyEvent>(), isTrue);
      expect(queue.length, 1);
    });

    test('clear should remove all events', () {
      final queue = EventQueue()
        ..enqueue(KeyEvent.fromString('enter'))
        ..enqueue(KeyEvent.fromString('escape'))
        ..enqueue(
          const MouseEvent(
            0,
            0,
            MouseButton(MouseButtonKind.left, MouseButtonAction.down),
          ),
        );

      expect(queue.length, 3);
      queue.clear();
      expect(queue.length, 0);
      expect(queue.dequeue<Event>(), isNull);
    });

    test('should maintain FIFO order', () {
      final queue = EventQueue();
      final event1 = KeyEvent.fromString('a');
      final event2 = KeyEvent.fromString('b');
      final event3 = KeyEvent.fromString('c');

      queue
        ..enqueue(event1)
        ..enqueue(event2)
        ..enqueue(event3);

      expect(queue.dequeue<Event>(), event1);
      expect(queue.dequeue<Event>(), event2);
      expect(queue.dequeue<Event>(), event3);
      expect(queue.dequeue<Event>(), isNull);
    });

    test('should drop oldest event when queue reaches maxSize', () {
      final queue = EventQueue(maxSize: 3);
      final event1 = KeyEvent.fromString('a');
      final event2 = KeyEvent.fromString('b');
      final event3 = KeyEvent.fromString('c');
      final event4 = KeyEvent.fromString('d');

      queue
        ..enqueue(event1)
        ..enqueue(event2)
        ..enqueue(event3);

      expect(queue.length, 3);

      queue.enqueue(event4);

      expect(queue.length, 3);
      expect(queue.dequeue<Event>(), event2);
      expect(queue.dequeue<Event>(), event3);
      expect(queue.dequeue<Event>(), event4);
      expect(queue.dequeue<Event>(), isNull);
    });

    test('should handle multiple overflow scenarios', () {
      final queue = EventQueue(maxSize: 2);

      final events = <KeyEvent>[];
      for (var i = 0; i < 5; i++) {
        final event = KeyEvent.fromString(String.fromCharCode(65 + i));
        events.add(event);
        queue.enqueue(event);
      }

      expect(queue.length, 2);

      final first = queue.dequeue<KeyEvent>();
      expect(first, events[3]);

      final second = queue.dequeue<KeyEvent>();
      expect(second, events[4]);

      expect(queue.dequeue<Event>(), isNull);
    });

    test('should handle mixed event types with type filtering', () {
      final queue = EventQueue();
      final key1 = KeyEvent.fromString('a');
      const mouse1 = MouseEvent(
        1,
        1,
        MouseButton(MouseButtonKind.left, MouseButtonAction.down),
      );
      final key2 = KeyEvent.fromString('b');
      const mouse2 = MouseEvent(
        2,
        2,
        MouseButton(MouseButtonKind.right, MouseButtonAction.up),
      );
      const focus = FocusEvent();

      queue
        ..enqueue(key1)
        ..enqueue(mouse1)
        ..enqueue(key2)
        ..enqueue(mouse2)
        ..enqueue(focus);

      expect(queue.length, 5);

      expect(queue.dequeue<KeyEvent>(), key1);
      expect(queue.length, 4);

      expect(queue.dequeue<KeyEvent>(), key2);
      expect(queue.length, 3);

      expect(queue.dequeue<MouseEvent>(), mouse1);
      expect(queue.length, 2);

      expect(queue.dequeue<FocusEvent>(), focus);
      expect(queue.length, 1);

      expect(queue.dequeue<MouseEvent>(), mouse2);
      expect(queue.length, 0);
    });

    test('should handle hasEvent with mixed types', () {
      final queue = EventQueue()
        ..enqueue(KeyEvent.fromString('a'))
        ..enqueue(
          const MouseEvent(
            0,
            0,
            MouseButton(MouseButtonKind.left, MouseButtonAction.down),
          ),
        );

      expect(queue.hasEvent<Event>(), isTrue);
      expect(queue.hasEvent<KeyEvent>(), isTrue);
      expect(queue.hasEvent<MouseEvent>(), isTrue);
      expect(queue.hasEvent<FocusEvent>(), isFalse);
      expect(queue.hasEvent<PasteEvent>(), isFalse);
    });

    test('dequeue should work after clear and re-enqueue', () {
      final queue = EventQueue();
      final event1 = KeyEvent.fromString('a');
      final event2 = KeyEvent.fromString('b');

      queue
        ..enqueue(event1)
        ..clear()
        ..enqueue(event2);

      expect(queue.length, 1);
      expect(queue.dequeue<KeyEvent>(), event2);
      expect(queue.length, 0);
    });

    test('should handle default maxSize of 1000', () {
      final queue = EventQueue();

      final events = <KeyEvent>[];
      for (var i = 0; i < 1000; i++) {
        final event = KeyEvent.fromString('a');
        events.add(event);
        queue.enqueue(event);
      }

      expect(queue.length, 1000);

      final overflowEvent = KeyEvent.fromString('b');
      queue.enqueue(overflowEvent);

      expect(queue.length, 1000);

      final first = queue.dequeue<KeyEvent>();
      expect(first, events[1]);
    });

    test('should handle InputEvent hierarchy', () {
      final queue = EventQueue();
      final keyEvent = KeyEvent.fromString('a');
      const mouseEvent = MouseEvent(
        0,
        0,
        MouseButton(MouseButtonKind.left, MouseButtonAction.down),
      );
      const pasteEvent = PasteEvent('pasted text');

      queue
        ..enqueue(keyEvent)
        ..enqueue(mouseEvent)
        ..enqueue(pasteEvent);

      expect(queue.hasEvent<InputEvent>(), isTrue);
      expect(queue.dequeue<InputEvent>(), keyEvent);
      expect(queue.dequeue<InputEvent>(), mouseEvent);
      expect(queue.dequeue<InputEvent>(), pasteEvent);
      expect(queue.dequeue<InputEvent>(), isNull);
    });

    test('should handle ResponseEvent hierarchy', () {
      final queue = EventQueue();
      const cursorPos = CursorPositionEvent(10, 20);
      const colorQuery = ColorQueryEvent(0xAB, 0xCD, 0xEF);

      queue
        ..enqueue(cursorPos)
        ..enqueue(colorQuery);

      expect(queue.hasEvent<ResponseEvent>(), isTrue);
      expect(queue.dequeue<ResponseEvent>(), cursorPos);
      expect(queue.dequeue<ResponseEvent>(), colorQuery);
      expect(queue.hasEvent<ResponseEvent>(), isFalse);
    });

    test('should handle NoneEvent as InternalEvent', () {
      final queue = EventQueue();
      const noneEvent = NoneEvent();

      queue.enqueue(noneEvent);

      expect(queue.hasEvent<InternalEvent>(), isTrue);
      expect(queue.hasEvent<NoneEvent>(), isTrue);
      expect(queue.dequeue<InternalEvent>(), noneEvent);
    });

    test('dispose should clear queue and close notifier', () async {
      final queue = EventQueue()
        ..enqueue(KeyEvent.fromString('a'))
        ..enqueue(KeyEvent.fromString('b'));

      expect(queue.length, 2);

      await queue.dispose();

      expect(queue.length, 0);
    });

    test('onEvent should emit when event enqueued', () async {
      final queue = EventQueue();
      var signalReceived = false;

      final subscription = queue.onEvent.listen((_) => signalReceived = true);

      queue.enqueue(KeyEvent.fromString('a'));

      await Future<void>.delayed(Duration.zero);

      expect(signalReceived, isTrue);

      await subscription.cancel();
      await queue.dispose();
    });

    test('onEvent should emit for each enqueue', () async {
      final queue = EventQueue();
      var signalCount = 0;

      final subscription = queue.onEvent.listen((_) => signalCount++);

      queue
        ..enqueue(KeyEvent.fromString('a'))
        ..enqueue(KeyEvent.fromString('b'))
        ..enqueue(KeyEvent.fromString('c'));

      await Future<void>.delayed(Duration.zero);

      expect(signalCount, 3);

      await subscription.cancel();
      await queue.dispose();
    });

    test('onEvent.first should complete when event enqueued', () async {
      final queue = EventQueue();

      final future = queue.onEvent.first;

      queue.enqueue(KeyEvent.fromString('x'));

      await expectLater(future, completes);

      await queue.dispose();
    });

    test('multiple listeners on onEvent should all receive signal', () async {
      final queue = EventQueue();
      var listener1Count = 0;
      var listener2Count = 0;

      final sub1 = queue.onEvent.listen((_) => listener1Count++);
      final sub2 = queue.onEvent.listen((_) => listener2Count++);

      queue.enqueue(KeyEvent.fromString('a'));

      await Future<void>.delayed(Duration.zero);

      expect(listener1Count, 1);
      expect(listener2Count, 1);

      await sub1.cancel();
      await sub2.cancel();
      await queue.dispose();
    });
  });
}
