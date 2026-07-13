import 'dart:async';
import 'dart:io';

import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';

/// Reason string used to skip SIGWINCH-based tests on Windows, which has no
/// such signal.
const _noSigwinch = 'SIGWINCH is not available on Windows';

/// All [ProbeQuery] values except [keep] — a skip set that leaves exactly one
/// query active, so `term.probe()` seeds only the capability under test.
Set<ProbeQuery> _skipAllBut(ProbeQuery keep) => ProbeQuery.values.where((q) => q != keep).toSet();

/// Polls [check] until it returns true or [timeout] elapses. Used instead of
/// a fixed sleep because real signal delivery is asynchronous relative to
/// Dart code.
Future<void> _pumpUntil(bool Function() check, {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!check() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('InteractiveTerm.enableResizeEvents() >', () {
    test(
      'installs no SIGWINCH watcher when termInfo reports in-band resize enabled',
      () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = term.probe(skip: _skipAllBut(ProbeQuery.inBandResize), deadline: 50);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QueryWindowResizeEvent(1)); // DECRPMStatus.enabled
            await probeFuture;

            term.enableResizeEvents();

            final received = <WindowResizeEvent>[];
            final sub = term.events.where((e) => e is WindowResizeEvent).cast<WindowResizeEvent>().listen(received.add);

            Process.killPid(pid, ProcessSignal.sigwinch);
            await Future<void>.delayed(const Duration(milliseconds: 300));

            expect(received, isEmpty);

            await sub.cancel();
            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      },
      skip: Platform.isWindows ? _noSigwinch : false,
    );

    test(
      'installs no SIGWINCH watcher when termInfo reports in-band resize disabled',
      () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = term.probe(skip: _skipAllBut(ProbeQuery.inBandResize), deadline: 50);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QueryWindowResizeEvent(2)); // DECRPMStatus.disabled
            await probeFuture;

            term.enableResizeEvents();

            final received = <WindowResizeEvent>[];
            final sub = term.events.where((e) => e is WindowResizeEvent).cast<WindowResizeEvent>().listen(received.add);

            Process.killPid(pid, ProcessSignal.sigwinch);
            await Future<void>.delayed(const Duration(milliseconds: 300));

            expect(received, isEmpty);

            await sub.cancel();
            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      },
      skip: Platform.isWindows ? _noSigwinch : false,
    );

    test(
      'installs a SIGWINCH watcher when termInfo is null, producing a WindowResizeEvent with pixels 0',
      () async {
        await mockedTest((term, _, _) async {
          expect(term.termInfo, isNull);
          term.enableResizeEvents();

          final received = <WindowResizeEvent>[];
          final sub = term.events.where((e) => e is WindowResizeEvent).cast<WindowResizeEvent>().listen(received.add);

          Process.killPid(pid, ProcessSignal.sigwinch);
          await _pumpUntil(() => received.isNotEmpty);

          expect(received, hasLength(1));
          final event = received.single;
          expect(event.heightPixels, 0);
          expect(event.widthPixels, 0);
          expect(event.heightChars, term.terminalLines);
          expect(event.widthChars, term.terminalColumns);

          // Also observable off the pull-based queue, not just the broadcast.
          expect(term.tryEvent<WindowResizeEvent>(), event);

          await sub.cancel();
          await term.dispose();
        });
      },
      skip: Platform.isWindows ? _noSigwinch : false,
    );

    test(
      'calling it twice installs at most one watcher, so one signal yields one event',
      () async {
        await mockedTest((term, _, _) async {
          term
            ..enableResizeEvents()
            ..enableResizeEvents();

          final received = <WindowResizeEvent>[];
          final sub = term.events.where((e) => e is WindowResizeEvent).cast<WindowResizeEvent>().listen(received.add);

          Process.killPid(pid, ProcessSignal.sigwinch);
          await _pumpUntil(() => received.isNotEmpty);
          // Give a hypothetical duplicate subscription a chance to also fire.
          await Future<void>.delayed(const Duration(milliseconds: 200));

          expect(received, hasLength(1));

          await sub.cancel();
          await term.dispose();
        });
      },
      skip: Platform.isWindows ? _noSigwinch : false,
    );
  });

  group('InteractiveTerm.disableResizeEvents() >', () {
    test(
      'cancels the watcher: a subsequent SIGWINCH produces nothing',
      () async {
        await mockedTest((term, _, _) async {
          term
            ..enableResizeEvents()
            ..disableResizeEvents();

          final received = <WindowResizeEvent>[];
          final sub = term.events.where((e) => e is WindowResizeEvent).cast<WindowResizeEvent>().listen(received.add);

          Process.killPid(pid, ProcessSignal.sigwinch);
          await Future<void>.delayed(const Duration(milliseconds: 300));

          expect(received, isEmpty);

          await sub.cancel();
          await term.dispose();
        });
      },
      skip: Platform.isWindows ? _noSigwinch : false,
    );
  });

  group('InteractiveTerm.dispose() >', () {
    test(
      'cancels the SIGWINCH watcher as a backstop: no throw, no late event',
      () async {
        await mockedTest((term, _, _) async {
          term.enableResizeEvents();
          await term.dispose();

          // A signal arriving after dispose must not resurrect delivery
          // (queue/broadcast are already torn down) and must not throw.
          Process.killPid(pid, ProcessSignal.sigwinch);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
      },
      skip: Platform.isWindows ? _noSigwinch : false,
    );
  });
}
