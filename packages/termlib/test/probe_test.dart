import 'dart:async';

import 'package:termansi/termansi.dart' as ansi;
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
            final future = probeTerminal(term, deadline: 1);
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
            final info1 = await probeTerminal(term, deadline: 1);
            final info2 = await probeTerminal(term, deadline: 1);

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
              deadline: 1,
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
              deadline: 1,
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
            final info = await probeTerminal(term, deadline: 1);

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
            eventController
              ..add(const ColorQueryEvent(10, 0xFF, 0x80, 0x40))
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence → early-exit

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
            eventController
              ..add(QuerySyncUpdateEvent(1))
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence → early-exit

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
            eventController
              ..add(QueryBracketedPasteEvent(1))
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence → early-exit

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
            eventController
              ..add(const QueryTerminalWindowSizeEvent(1920, 1080))
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence → early-exit

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

    group('batch behavior >', () {
      // Probe everything except [keep]. DA1 is still sent as the fence even
      // though deviceAttrs lands in the skip set.
      Set<ProbeQuery> allBut(Set<ProbeQuery> keep) => ProbeQuery.values.toSet()..removeAll(keep);

      test('fg and bg disambiguated by .code in one batch', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            final probeFuture = probeTerminal(
              term,
              skip: allBut({ProbeQuery.foregroundColor, ProbeQuery.backgroundColor}),
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController
              ..add(const ColorQueryEvent(10, 0xFF, 0x00, 0x00)) // fg
              ..add(const ColorQueryEvent(11, 0x00, 0x00, 0xFF)) // bg
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence

            final info = await probeFuture;

            // Two identically-typed replies land in distinct slots, keyed by .code.
            expect((info.foregroundColor as Supported<Color>).value, Color.fromRGBComponent(0xFF, 0x00, 0x00));
            expect((info.backgroundColor as Supported<Color>).value, Color.fromRGBComponent(0x00, 0x00, 0xFF));

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('strays during a probe are requeued (drainable afterwards)', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            // Skip everything; only the DA1 fence is sent.
            final probeFuture = probeTerminal(term, skip: ProbeQuery.values.toSet());

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController
              ..add(KeyEvent.fromString('a')) // stray input
              ..add(const ColorQueryEvent(12, 0x11, 0x22, 0x33)) // cursor color: never queried → stray
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence

            await probeFuture;

            // Both strays fell through to the queue and are drainable.
            expect(term.tryEvent<KeyEvent>(), isA<KeyEvent>());
            final stray = term.tryEvent<ColorQueryEvent>();
            expect(stray, isA<ColorQueryEvent>());
            expect(stray!.code, 12);

            await term.dispose();
          },
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('writes a single batch with DA1 (CSI c) last', () async {
        final eventController = StreamController<Event>.broadcast();
        final out = BufferTermSink();

        await mockedTest(
          (term, _, _) async {
            // No fence emitted → resolves on the small deadline; we only inspect
            // what was written.
            await probeTerminal(term, deadline: 30);

            final output = out.output;
            // Every non-DA1 query escape is present...
            for (final esc in <String>[
              ansi.Term.requestTermVersion,
              ansi.Term.queryOSCColors(10),
              ansi.Term.queryOSCColors(11),
              ansi.Term.querySyncUpdate,
              ansi.Term.requestKeyboardCapabilities,
              ansi.Term.queryWindowSizePixels,
              ansi.Term.queryUnicodeCore,
              ansi.Term.queryColorScheme,
              ansi.Term.queryInBandResize,
              ansi.Term.queryBracketedPaste,
            ]) {
              expect(output, contains(esc));
            }
            // ...and DA1 is the final query in the buffer (the fence).
            expect(output.endsWith(ansi.Term.queryPrimaryDeviceAttributes), isTrue);

            await term.dispose();
          },
          stdout: out,
          eventSource: eventController.stream,
        );

        await eventController.close();
      });

      test('early-exit: resolves on the fence, not the (large) deadline', () async {
        final eventController = StreamController<Event>.broadcast();

        await mockedTest(
          (term, _, _) async {
            // Deadline is 30s; without the fence early-exit this would hang.
            final probeFuture = probeTerminal(
              term,
              skip: allBut({ProbeQuery.foregroundColor}),
              deadline: 30000,
            );

            await Future<void>.delayed(const Duration(milliseconds: 10));
            eventController
              ..add(const ColorQueryEvent(10, 0x01, 0x02, 0x03))
              ..add(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])); // fence

            // Completes promptly, well under the 30s deadline.
            final info = await probeFuture.timeout(const Duration(seconds: 2));
            expect(info.foregroundColor, isA<Supported<Color>>());

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
            await probeTerminal(term, deadline: 1);

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
            final probeFuture = term.probe(skip: only(ProbeQuery.bracketedPaste), deadline: 50);
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
            final probeFuture = term.probe(skip: only(ProbeQuery.inBandResize), deadline: 50);
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
            final probeFuture = term.probe(skip: only(ProbeQuery.bracketedPaste), deadline: 50);
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

  group('TermInfo DA1-derived flags >', () {
    TermInfo infoWith(DeviceAttributes attrs) =>
        (TermInfoBuilder()..set(ProbeQuery.deviceAttrs, Supported(attrs))).build();

    test('clipboardOsc52 true when DA1 lists param 52', () {
      final info = infoWith(
        const DeviceAttributes(DeviceAttributeType.vt220, [
          DeviceAttributeParams.ansiColor,
          DeviceAttributeParams.clipboard,
        ]),
      );
      expect(info.clipboardOsc52, const Supported(true));
    });

    test('clipboardOsc52 false when DA1 omits param 52', () {
      final info = infoWith(
        const DeviceAttributes(DeviceAttributeType.vt220, [DeviceAttributeParams.ansiColor]),
      );
      expect(info.clipboardOsc52, const Supported(false));
    });

    test('sixelGraphics true when DA1 lists param 4', () {
      final info = infoWith(
        const DeviceAttributes(DeviceAttributeType.vt220, [DeviceAttributeParams.sixelGraphics]),
      );
      expect(info.sixelGraphics, const Supported(true));
      expect(info.clipboardOsc52, const Supported(false));
    });

    test('propagates Unavailable reason when DA1 itself is unavailable', () {
      final info =
          (TermInfoBuilder()
                ..set(ProbeQuery.deviceAttrs, const Unavailable<DeviceAttributes>(UnavailableReason.timeout)))
              .build();
      expect(info.clipboardOsc52, const Unavailable<bool>(UnavailableReason.timeout));
      expect(info.sixelGraphics, const Unavailable<bool>(UnavailableReason.timeout));
    });

    test('Unavailable(skipped) when DA1 absent from results', () {
      final info = TermInfoBuilder().build();
      expect(info.clipboardOsc52, const Unavailable<bool>(UnavailableReason.skipped));
    });
  });
}
