import 'package:termparser/src/engine/event_queue.dart';
import 'package:termparser/src/events.dart';
import 'package:test/test.dart';

void main() {
  group('EventQueue >', () {
    test('add and poll', () {
      final queue = EventQueue();
      const event = NoneEvent();

      queue.add(event);
      expect(queue.hasEvents, true);
      expect(queue.count, 1);

      final polled = queue.poll();
      expect(polled, event);
      expect(queue.hasEvents, false);
      expect(queue.count, 0);
    });

    test('poll empty queue returns null', () {
      final queue = EventQueue();
      expect(queue.poll(), null);
    });

    test('peek without removing', () {
      final queue = EventQueue();
      const event = NoneEvent();

      queue.add(event);
      expect(queue.peek(), event);
      expect(queue.hasEvents, true);
      expect(queue.count, 1);
    });

    test('peek empty queue returns null', () {
      final queue = EventQueue();
      expect(queue.peek(), null);
    });

    test('drain all events', () {
      final queue = EventQueue();
      const event1 = NoneEvent();
      const event2 = NoneEvent();

      queue
        ..add(event1)
        ..add(event2);

      final events = queue.drain();
      expect(events.length, 2);
      expect(events[0], event1);
      expect(events[1], event2);
      expect(queue.hasEvents, false);
      expect(queue.count, 0);
    });

    test('drain empty queue returns empty list', () {
      final queue = EventQueue();
      final events = queue.drain();
      expect(events.isEmpty, true);
    });

    test('FIFO order', () {
      final queue = EventQueue();
      const event1 = NoneEvent();
      const event2 = NoneEvent();
      const event3 = NoneEvent();

      queue
        ..add(event1)
        ..add(event2)
        ..add(event3);

      expect(queue.poll(), event1);
      expect(queue.poll(), event2);
      expect(queue.poll(), event3);
      expect(queue.poll(), null);
    });
  });
}
