import 'dart:async';

import 'package:termlib/src/probe/probe_collector.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('runProbeBatch tap wiring >', () {
    test('writes the batch and early-exits on the DA1 fence', () async {
      final events = StreamController<Event>.broadcast();
      final out = BufferTermSink();

      await mockedTest(
        (term, _, _) async {
          final collector = ProbeCollector({ProbeQuery.terminalVersion});
          // Large deadline: only the fence should end the wait, fast.
          final batch = term.runProbeBatch('BATCH-ESCAPES', collector, const Duration(seconds: 30));

          await Future<void>.delayed(const Duration(milliseconds: 10));
          events
            ..add(const NameAndVersionEvent('xterm(1)'))
            ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, []));

          await batch; // resolves on the fence, well before the 30s deadline

          expect(out.output, contains('BATCH-ESCAPES'));
          expect(collector.results[ProbeQuery.terminalVersion], isA<NameAndVersionEvent>());
          expect(collector.results[ProbeQuery.deviceAttrs], isA<PrimaryDeviceAttributesEvent>());

          await term.dispose();
        },
        stdout: out,
        eventSource: events.stream,
      );

      await events.close();
    });

    test('consumed probe replies bypass the queue; strays reach it', () async {
      final events = StreamController<Event>.broadcast();

      await mockedTest(
        (term, _, _) async {
          final collector = ProbeCollector({ProbeQuery.terminalVersion});
          final batch = term.runProbeBatch('B', collector, const Duration(seconds: 30));

          await Future<void>.delayed(const Duration(milliseconds: 10));
          events
            ..add(KeyEvent.fromString('a')) // stray, mid-probe
            ..add(const NameAndVersionEvent('xterm(1)')) // consumed reply
            ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence

          await batch;

          // Stray fell through to the queue and is drainable.
          expect(term.tryEvent<KeyEvent>(), isA<KeyEvent>());
          // Consumed replies never hit the queue.
          expect(term.tryEvent<NameAndVersionEvent>(), isNull);
          expect(term.tryEvent<PrimaryDeviceAttributesEvent>(), isNull);

          await term.dispose();
        },
        eventSource: events.stream,
      );

      await events.close();
    });

    test('tap is removed after the batch: later replies become queue events', () async {
      final events = StreamController<Event>.broadcast();

      await mockedTest(
        (term, _, _) async {
          final collector = ProbeCollector({ProbeQuery.terminalVersion});
          final batch = term.runProbeBatch('B', collector, const Duration(seconds: 30));

          await Future<void>.delayed(const Duration(milliseconds: 10));
          events.add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence
          await batch;

          // After the batch the tap is gone, so a probe-typed reply is enqueued.
          events.add(QuerySyncUpdateEvent(1));
          final e = await term.awaitEvent<QuerySyncUpdateEvent>(timeout: const Duration(seconds: 1));
          expect(e, isA<QuerySyncUpdateEvent>());

          await term.dispose();
        },
        eventSource: events.stream,
      );

      await events.close();
    });

    test('no fence: resolves on the batch deadline (fallback)', () async {
      final events = StreamController<Event>.broadcast();

      await mockedTest(
        (term, _, _) async {
          final collector = ProbeCollector({ProbeQuery.terminalVersion});
          // Small deadline, no DA1 emitted → onTimeout no-op resolves the batch.
          await term.runProbeBatch('B', collector, const Duration(milliseconds: 20));

          expect(collector.results, isEmpty);
          await term.dispose();
        },
        eventSource: events.stream,
      );

      await events.close();
    });
  });
}
