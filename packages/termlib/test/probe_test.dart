import 'dart:async';

import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('probeTerminal() >', () {
    group('basic behavior >', () {
      test('Term.open returns PipedTerm when !hasTerminal', () async {
        // Probe now takes InteractiveTerm — piped mode is ruled out at the
        // type level rather than by a runtime StateError.
        await mockedPipedTest((term, _, _) {
          expect(term, isA<PipedTerm>());
        });
      });

      test('returns Future<TermInfo>', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final future = probeTerminal(term, timeout: 1);
            expect(future, isA<Future<TermInfo>>());
            await future;
            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('multiple calls return independent results', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final info1 = await probeTerminal(term, timeout: 1);
            final info2 = await probeTerminal(term, timeout: 1);

            expect(identical(info1, info2), isFalse);
            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });
    });

    group('skip parameter >', () {
      test('skipped queries marked as unavailable(skipped)', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final info = await probeTerminal(
              term,
              skip: {ProbeQuery.syncUpdate, ProbeQuery.unicodeCore},
              timeout: 1,
            );

            expect(info.syncUpdate, isA<Unavailable<SyncUpdateStatus>>());
            expect((info.syncUpdate as Unavailable).reason, UnavailableReason.skipped);
            expect(info.unicodeCore, isA<Unavailable<UnicodeCoreStatus>>());
            expect((info.unicodeCore as Unavailable).reason, UnavailableReason.skipped);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('non-skipped queries run and timeout', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final info = await probeTerminal(
              term,
              skip: {
                ProbeQuery.terminalVersion,
                ProbeQuery.foregroundColor,
                ProbeQuery.backgroundColor,
                ProbeQuery.syncUpdate,
                ProbeQuery.keyboardCapabilities,
                ProbeQuery.windowSizePixels,
                ProbeQuery.unicodeCore,
              },
              timeout: 1,
            );

            expect(info.deviceAttrs, isA<Unavailable<DeviceAttributes>>());
            expect((info.deviceAttrs as Unavailable).reason, UnavailableReason.timeout);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });
    });

    group('timeout parameter >', () {
      test('queries timeout with Unavailable(timeout)', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final info = await probeTerminal(term, timeout: 1);

            expect(info.deviceAttrs, isA<Unavailable<DeviceAttributes>>());
            expect((info.deviceAttrs as Unavailable).reason, UnavailableReason.timeout);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });
    });

    group('successful queries >', () {
      test('deviceAttrs populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = probeTerminal(
              term,
              skip: {
                ProbeQuery.terminalVersion,
                ProbeQuery.foregroundColor,
                ProbeQuery.backgroundColor,
                ProbeQuery.syncUpdate,
                ProbeQuery.keyboardCapabilities,
                ProbeQuery.windowSizePixels,
                ProbeQuery.unicodeCore,
              },
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(
              const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, []),
            );

            final info = await probeFuture;

            expect(info.deviceAttrs, isA<Supported<DeviceAttributes>>());
            final attrs = (info.deviceAttrs as Supported<DeviceAttributes>).value;
            expect(attrs.type, DeviceAttributeType.vt220);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('foregroundColor populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = probeTerminal(
              term,
              skip: {
                ProbeQuery.deviceAttrs,
                ProbeQuery.terminalVersion,
                ProbeQuery.backgroundColor,
                ProbeQuery.syncUpdate,
                ProbeQuery.keyboardCapabilities,
                ProbeQuery.windowSizePixels,
                ProbeQuery.unicodeCore,
              },
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(const ColorQueryEvent(10, 0xFF, 0x80, 0x40));

            final info = await probeFuture;

            expect(info.foregroundColor, isA<Supported<Color>>());
            final color = (info.foregroundColor as Supported<Color>).value;
            expect(color.kind, ColorKind.rgb);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('syncUpdate populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = probeTerminal(
              term,
              skip: {
                ProbeQuery.deviceAttrs,
                ProbeQuery.terminalVersion,
                ProbeQuery.foregroundColor,
                ProbeQuery.backgroundColor,
                ProbeQuery.keyboardCapabilities,
                ProbeQuery.windowSizePixels,
                ProbeQuery.unicodeCore,
              },
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QuerySyncUpdateEvent(1));

            final info = await probeFuture;

            expect(info.syncUpdate, isA<Supported<SyncUpdateStatus>>());
            final status = (info.syncUpdate as Supported<SyncUpdateStatus>).value;
            expect(status, SyncUpdateStatus.enabled);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('bracketedPaste populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = probeTerminal(
              term,
              skip: {
                ProbeQuery.deviceAttrs,
                ProbeQuery.terminalVersion,
                ProbeQuery.foregroundColor,
                ProbeQuery.backgroundColor,
                ProbeQuery.syncUpdate,
                ProbeQuery.keyboardCapabilities,
                ProbeQuery.windowSizePixels,
                ProbeQuery.unicodeCore,
                ProbeQuery.colorScheme,
                ProbeQuery.inBandResize,
              },
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QueryBracketedPasteEvent(1));

            final info = await probeFuture;

            expect(info.bracketedPaste, isA<Supported<BracketedPasteStatus>>());
            final status = (info.bracketedPaste as Supported<BracketedPasteStatus>).value;
            expect(status, BracketedPasteStatus.enabled);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('windowSizePixels populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = probeTerminal(
              term,
              skip: {
                ProbeQuery.deviceAttrs,
                ProbeQuery.terminalVersion,
                ProbeQuery.foregroundColor,
                ProbeQuery.backgroundColor,
                ProbeQuery.syncUpdate,
                ProbeQuery.keyboardCapabilities,
                ProbeQuery.unicodeCore,
              },
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(const QueryTerminalWindowSizeEvent(1920, 1080));

            final info = await probeFuture;

            expect(info.windowSizePixels, isA<Supported<WindowSize>>());
            final size = (info.windowSizePixels as Supported<WindowSize>).value;
            expect(size.width, 1920);
            expect(size.height, 1080);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });
    });

    group('raw mode >', () {
      test('probe enables/disables raw mode', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, tos) async {
            await probeTerminal(term, timeout: 1);

            expect(tos.callStack, contains('enableRawMode'));
            expect(tos.callStack, contains('disableRawMode'));

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });
    });

    // term.probe() (the InteractiveTerm method, not the bare probeTerminal
    // function) seeds the live tracked mode state from the probe result, so
    // later withModes save/restore starts from the terminal's actual state.
    // Seeding is internal; it is observed here through restore behavior: a
    // scope that force-disables a seeded-on mode must re-enable it on exit.
    group('mode seeding (term.probe) >', () {
      // Probe only [keep]; everything else is skipped.
      Set<ProbeQuery> only(ProbeQuery keep) => ProbeQuery.values.where((q) => q != keep).toSet();

      test('seeds bracketed paste enabled → withModes restores it on', () async {
        final eventController = StreamController<Event>.broadcast();
        final out = BufferTermSink();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = term.probe(skip: only(ProbeQuery.bracketedPaste), timeout: 50);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QueryBracketedPasteEvent(1)); // enabled
            await probeFuture;

            await term.withModes(() async {}, bracketedPaste: false);
            await term.dispose();
          },
          stdout: out,
          eventSource: eventController.stream,
        );

        // Entry disabled it; exit restored to the seeded-on state.
        expect(out.output, contains('\x1b[?2004h'));
        await eventController.close();
      });

      test('seeds in-band resize enabled → withModes restores it on', () async {
        final eventController = StreamController<Event>.broadcast();
        final out = BufferTermSink();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = term.probe(skip: only(ProbeQuery.inBandResize), timeout: 50);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QueryWindowResizeEvent(1)); // enabled
            await probeFuture;

            await term.withModes(() async {}, inBandResize: false);
            await term.dispose();
          },
          stdout: out,
          eventSource: eventController.stream,
        );

        expect(out.output, contains('\x1b[?2048h'));
        await eventController.close();
      });

      test('an unknown (notRecognized) result is not seeded → restores off', () async {
        final eventController = StreamController<Event>.broadcast();
        final out = BufferTermSink();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = term.probe(skip: only(ProbeQuery.bracketedPaste), timeout: 50);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController.add(QueryBracketedPasteEvent(0)); // notRecognized → unknown
            await probeFuture;

            await term.withModes(() async {}, bracketedPaste: false);
            await term.dispose();
          },
          stdout: out,
          eventSource: eventController.stream,
        );

        // Not seeded: prior stays at the default (off), so exit re-disables.
        expect(out.output, isNot(contains('\x1b[?2004h')));
        await eventController.close();
      });
    });
  });

  group('QueryResult >', () {
    test('Supported toString', () {
      const supported = Supported<String>('test');
      expect(supported.toString(), 'Supported<String>(test)');
    });

    test('Supported equality', () {
      const a = Supported<int>(42);
      const b = Supported<int>(42);
      const c = Supported<int>(99);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('Unavailable toString', () {
      const unavailable = Unavailable<String>(UnavailableReason.timeout);
      expect(unavailable.toString(), 'Unavailable<String>(UnavailableReason.timeout)');
    });

    test('Unavailable equality', () {
      const a = Unavailable<int>(UnavailableReason.timeout);
      const b = Unavailable<int>(UnavailableReason.timeout);
      const c = Unavailable<int>(UnavailableReason.skipped);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ProbeQuery >', () {
    test('all values exist', () {
      expect(ProbeQuery.values, hasLength(11));
      expect(ProbeQuery.values, contains(ProbeQuery.deviceAttrs));
      expect(ProbeQuery.values, contains(ProbeQuery.terminalVersion));
      expect(ProbeQuery.values, contains(ProbeQuery.foregroundColor));
      expect(ProbeQuery.values, contains(ProbeQuery.backgroundColor));
      expect(ProbeQuery.values, contains(ProbeQuery.syncUpdate));
      expect(ProbeQuery.values, contains(ProbeQuery.keyboardCapabilities));
      expect(ProbeQuery.values, contains(ProbeQuery.windowSizePixels));
      expect(ProbeQuery.values, contains(ProbeQuery.unicodeCore));
      expect(ProbeQuery.values, contains(ProbeQuery.colorScheme));
      expect(ProbeQuery.values, contains(ProbeQuery.inBandResize));
      expect(ProbeQuery.values, contains(ProbeQuery.bracketedPaste));
    });
  });

  group('helper types >', () {
    test('DeviceAttributes equality', () {
      const a = DeviceAttributes(
        DeviceAttributeType.vt220,
        <DeviceAttributeParams>[DeviceAttributeParams.columns132],
      );
      const b = DeviceAttributes(
        DeviceAttributeType.vt220,
        <DeviceAttributeParams>[DeviceAttributeParams.columns132],
      );
      const c = DeviceAttributes(
        DeviceAttributeType.vt320,
        <DeviceAttributeParams>[DeviceAttributeParams.columns132],
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('DeviceAttributes toString', () {
      const attrs = DeviceAttributes(DeviceAttributeType.vt220, <DeviceAttributeParams>[]);
      expect(attrs.toString(), contains('DeviceAttributes'));
    });

    test('KeyboardFlags equality', () {
      const a = KeyboardFlags(disambiguateEscapeCodes: true);
      const b = KeyboardFlags(disambiguateEscapeCodes: true);
      const c = KeyboardFlags(reportEventTypes: true);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('KeyboardFlags toString', () {
      const flags = KeyboardFlags();
      expect(flags.toString(), contains('KeyboardFlags'));
    });

    test('WindowSize equality', () {
      const a = WindowSize(800, 600);
      const b = WindowSize(800, 600);
      const c = WindowSize(1024, 768);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('WindowSize toString', () {
      const size = WindowSize(800, 600);
      expect(size.toString(), 'WindowSize(800, 600)');
    });

    test('InBandResizeStatus values', () {
      expect(InBandResizeStatus.values, hasLength(3));
      expect(InBandResizeStatus.values, contains(InBandResizeStatus.enabled));
      expect(InBandResizeStatus.values, contains(InBandResizeStatus.disabled));
      expect(InBandResizeStatus.values, contains(InBandResizeStatus.unknown));
    });

    test('BracketedPasteStatus values', () {
      expect(BracketedPasteStatus.values, hasLength(3));
      expect(BracketedPasteStatus.values, contains(BracketedPasteStatus.enabled));
      expect(BracketedPasteStatus.values, contains(BracketedPasteStatus.disabled));
      expect(BracketedPasteStatus.values, contains(BracketedPasteStatus.unknown));
    });
  });
}
