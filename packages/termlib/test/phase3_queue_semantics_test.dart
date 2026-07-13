import 'dart:async';

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

const _leftDrag = MouseButton(MouseButtonKind.left, MouseButtonAction.drag);
const _rightDrag = MouseButton(MouseButtonKind.right, MouseButtonAction.drag);
const _leftDown = MouseButton(MouseButtonKind.left, MouseButtonAction.down);
const _leftUp = MouseButton(MouseButtonKind.left, MouseButtonAction.up);
const _moved = MouseButton(MouseButtonKind.none, MouseButtonAction.moved);
const _wheelUp = MouseButton(MouseButtonKind.none, MouseButtonAction.wheelUp);

void main() {
  group('Phase 3 — coalesce-at-enqueue', () {
    test('MouseEvent moved samples collapse to the latest', () {
      final queue = EventQueue();
      for (var i = 0; i < 100; i++) {
        queue.enqueue(MouseEvent(i, i, _moved));
      }
      expect(queue.length, 1);
      final ev = queue.dequeue<MouseEvent>();
      expect(ev?.x, 99);
      expect(ev?.y, 99);
    });

    test('MouseEvent drag samples collapse only within same button-state', () {
      final queue = EventQueue()
        ..enqueue(const MouseEvent(1, 1, _leftDrag))
        ..enqueue(const MouseEvent(2, 2, _leftDrag))
        ..enqueue(const MouseEvent(3, 3, _rightDrag))
        ..enqueue(const MouseEvent(4, 4, _rightDrag));
      expect(queue.length, 2);
      final left = queue.dequeue<MouseEvent>();
      expect(left?.button.button, MouseButtonKind.left);
      expect(left?.x, 2);
      final right = queue.dequeue<MouseEvent>();
      expect(right?.button.button, MouseButtonKind.right);
      expect(right?.x, 4);
    });

    test('button-state transitions preserved (down → drag → up → drag)', () {
      final queue = EventQueue()
        ..enqueue(const MouseEvent(0, 0, _leftDown))
        ..enqueue(const MouseEvent(1, 1, _leftDrag))
        ..enqueue(const MouseEvent(2, 2, _leftDrag))
        ..enqueue(const MouseEvent(3, 3, _leftUp))
        ..enqueue(const MouseEvent(4, 4, _leftDrag));
      // down (kept), drag×2 → drag@(2,2), up (kept), drag (kept) = 4 events
      expect(queue.length, 4);
      expect(queue.dequeue<MouseEvent>()?.button.action, MouseButtonAction.down);
      final drag = queue.dequeue<MouseEvent>();
      expect(drag?.button.action, MouseButtonAction.drag);
      expect(drag?.x, 2);
      expect(queue.dequeue<MouseEvent>()?.button.action, MouseButtonAction.up);
      expect(queue.dequeue<MouseEvent>()?.button.action, MouseButtonAction.drag);
    });

    test('discrete MouseEvents (down/up/wheel) never coalesce', () {
      final queue = EventQueue()
        ..enqueue(const MouseEvent(0, 0, _leftDown))
        ..enqueue(const MouseEvent(1, 1, _leftDown))
        ..enqueue(const MouseEvent(2, 2, _wheelUp))
        ..enqueue(const MouseEvent(3, 3, _wheelUp));
      expect(queue.length, 4);
    });

    test('coalesceMotion=false buffers every sample', () {
      final queue = EventQueue(coalesceMotion: false);
      for (var i = 0; i < 100; i++) {
        queue.enqueue(MouseEvent(i, i, _moved));
      }
      expect(queue.length, 100);
    });

    test('WindowResizeEvent collapses to the latest', () {
      final queue = EventQueue();
      for (var i = 1; i <= 50; i++) {
        queue.enqueue(WindowResizeEvent(i, i));
      }
      expect(queue.length, 1);
      final ev = queue.dequeue<WindowResizeEvent>();
      expect(ev?.heightChars, 50);
      expect(ev?.widthChars, 50);
    });

    test('two consecutive WindowResizeEvents collapse to one', () {
      final queue = EventQueue()
        ..enqueue(const WindowResizeEvent(24, 80))
        ..enqueue(const WindowResizeEvent(30, 100));
      expect(queue.length, 1);
      final ev = queue.dequeue<WindowResizeEvent>();
      expect(ev?.heightChars, 30);
      expect(ev?.widthChars, 100);
    });

    test('coalesce only collapses against the immediate tail', () {
      final queue = EventQueue()
        ..enqueue(const MouseEvent(1, 1, _moved))
        ..enqueue(KeyEvent.fromString('a'))
        ..enqueue(const MouseEvent(2, 2, _moved));
      expect(queue.length, 3);
    });
  });

  group('Phase 3 — overflow signal (queue-level)', () {
    test('drop-oldest flushes one QueueOverflowEvent on next dequeue', () {
      final overflows = <QueueOverflowEvent>[];
      final queue = EventQueue(
        maxSize: 3,
        onOverflow: (type, dropped) {
          overflows.add(QueueOverflowEvent(type: type, dropped: dropped));
        },
      );
      for (var i = 0; i < 4; i++) {
        queue.enqueue(KeyEvent.fromString('a'));
      }
      expect(queue.length, 3);
      expect(overflows, isEmpty);
      queue.dequeue<KeyEvent>();
      expect(overflows.length, 1);
      expect(overflows.first.type, KeyEvent);
      expect(overflows.first.dropped, 1);
    });

    test('rate-limit: many drops between dequeues collapse to a single event', () {
      final overflows = <QueueOverflowEvent>[];
      final queue = EventQueue(
        maxSize: 5,
        onOverflow: (type, dropped) {
          overflows.add(QueueOverflowEvent(type: type, dropped: dropped));
        },
      );
      for (var i = 0; i < 1005; i++) {
        queue.enqueue(KeyEvent.fromString('a'));
      }
      queue.dequeue<KeyEvent>();
      expect(overflows.length, 1);
      expect(overflows.first.dropped, 1000);
    });

    test('subsequent overflows after a flush emit again', () {
      final overflows = <QueueOverflowEvent>[];
      final queue = EventQueue(
        maxSize: 2,
        onOverflow: (type, dropped) {
          overflows.add(QueueOverflowEvent(type: type, dropped: dropped));
        },
      );
      for (var i = 0; i < 3; i++) {
        queue.enqueue(KeyEvent.fromString('a'));
      }
      queue.dequeue<KeyEvent>();
      // After dequeue: 1 in queue, pendingDrops=0.
      // Enqueue 3 more: queue grows to 2, then drop, drop → 2 drops.
      for (var i = 0; i < 3; i++) {
        queue.enqueue(KeyEvent.fromString('a'));
      }
      queue.dequeue<KeyEvent>();
      expect(overflows.length, 2);
      expect(overflows.map((e) => e.dropped).toList(), [1, 2]);
    });
  });

  group('Phase 3 — overflow broadcast wiring', () {
    test('QueueOverflowEvent appears on InteractiveTerm.events', () async {
      final controller = StreamController<Event>();
      final term =
          Term.open(
                backend: TermBackend.fake(
                  eventSource: controller.stream,
                  maxQueueSize: 3,
                ),
              )
              as InteractiveTerm;

      final received = <Event>[];
      final sub = term.events.listen(received.add);

      for (var i = 0; i < 5; i++) {
        controller.add(KeyEvent.fromString('a'));
      }
      await Future<void>.delayed(Duration.zero);
      term.tryEvent<KeyEvent>();
      await Future<void>.delayed(Duration.zero);

      final overflow = received.whereType<QueueOverflowEvent>().toList();
      expect(overflow.length, 1);
      expect(overflow.first.type, KeyEvent);
      expect(overflow.first.dropped, 2);

      await sub.cancel();
      await controller.close();
      await term.dispose();
    });
  });

  group('Phase 3 — diagnostics & exceptions', () {
    test('InteractiveTerm.queueLength reflects buffered events', () async {
      final controller = StreamController<Event>();
      final term =
          Term.open(
                backend: TermBackend.fake(eventSource: controller.stream),
              )
              as InteractiveTerm;

      expect(term.queueLength, 0);
      controller
        ..add(KeyEvent.fromString('a'))
        ..add(KeyEvent.fromString('b'));
      await Future<void>.delayed(Duration.zero);
      expect(term.queueLength, 2);

      term.tryEvent<KeyEvent>();
      expect(term.queueLength, 1);

      await controller.close();
      await term.dispose();
    });

    test('TermBackend.maxQueueSize honored end-to-end', () async {
      final controller = StreamController<Event>();
      final term =
          Term.open(
                backend: TermBackend.fake(eventSource: controller.stream, maxQueueSize: 10),
              )
              as InteractiveTerm;

      for (var i = 0; i < 25; i++) {
        controller.add(KeyEvent.fromString('a'));
      }
      await Future<void>.delayed(Duration.zero);
      expect(term.queueLength, 10);

      await controller.close();
      await term.dispose();
    });

    test('awaitEvent during dispose throws TermDisposed', () async {
      final term = Term.open(backend: TermBackend.fake()) as InteractiveTerm;
      final future = term.awaitEvent<KeyEvent>();
      final expectation = expectLater(future, throwsA(isA<TermDisposed>()));
      await term.dispose();
      await expectation;
    });

    test('TerminalNotInteractive thrown by TermRunner.build on piped tty', () {
      final runner = TermRunner(backend: TermBackend.fake(hasTerminal: false));
      expect(runner.build, throwsA(isA<TerminalNotInteractive>()));
    });
  });
}
