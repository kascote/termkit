import 'dart:async';

import 'package:termlib/src/shared/terminal_overrides.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';
import 'termlib_mock.dart';

void main() {
  group('probeTerminal() >', () {
    group('basic behavior >', () {
      test('throws StateError when !hasTerminal', () async {
        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();
            expect(() => probeTerminal(term), throwsStateError);
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: false,
        );
      });

      test('returns Future<TermInfo>', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

            // Start probe with very short timeout so it completes quickly
            final future = probeTerminal(term, timeout: 1);

            expect(future, isA<Future<TermInfo>>());

            // Let it complete
            await future;
            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });

      test('multiple calls return independent results', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

            final info1 = await probeTerminal(term, timeout: 1);
            final info2 = await probeTerminal(term, timeout: 1);

            // Each call returns a new TermInfo instance
            expect(identical(info1, info2), isFalse);
            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });
    });

    group('skip parameter >', () {
      test('skipped queries marked as unavailable(skipped)', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

            final info = await probeTerminal(
              term,
              skip: {ProbeQuery.syncUpdate, ProbeQuery.unicodeCore},
              timeout: 1,
            );

            expect(info.syncUpdate, isA<Unavailable<SyncUpdateStatus>>());
            expect(
              (info.syncUpdate as Unavailable).reason,
              UnavailableReason.skipped,
            );
            expect(info.unicodeCore, isA<Unavailable<UnicodeCoreStatus>>());
            expect(
              (info.unicodeCore as Unavailable).reason,
              UnavailableReason.skipped,
            );

            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });

      test('non-skipped queries run and timeout', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

            // Skip all but deviceAttrs
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

            // deviceAttrs should timeout (not skipped)
            expect(info.deviceAttrs, isA<Unavailable<DeviceAttributes>>());
            expect(
              (info.deviceAttrs as Unavailable).reason,
              UnavailableReason.timeout,
            );

            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });
    });

    group('timeout parameter >', () {
      test('queries timeout with Unavailable(timeout)', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

            final info = await probeTerminal(term, timeout: 1);

            // All queries should timeout since no responses injected
            expect(info.deviceAttrs, isA<Unavailable<DeviceAttributes>>());
            expect(
              (info.deviceAttrs as Unavailable).reason,
              UnavailableReason.timeout,
            );

            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });
    });

    group('successful queries >', () {
      test('deviceAttrs populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

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

            // Inject response after small delay
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
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });

      test('foregroundColor populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

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
            // ColorQueryEvent with RGB values (0-255 range)
            eventController.add(const ColorQueryEvent(0xFF, 0x80, 0x40));

            final info = await probeFuture;

            expect(info.foregroundColor, isA<Supported<Color>>());
            final color = (info.foregroundColor as Supported<Color>).value;
            expect(color.kind, ColorKind.rgb);

            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });

      test('syncUpdate populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

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
            // DECRPMStatus.enabled has value 1
            eventController.add(QuerySyncUpdateEvent(1));

            final info = await probeFuture;

            expect(info.syncUpdate, isA<Supported<SyncUpdateStatus>>());
            final status = (info.syncUpdate as Supported<SyncUpdateStatus>).value;
            expect(status, SyncUpdateStatus.enabled);

            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });

      test('windowSizePixels populated on response', () async {
        final eventController = StreamController<Event>.broadcast();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

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
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: TermOsMock(),
          hasTerminal: true,
          eventStream: eventController,
        );

        await eventController.close();
      });
    });

    group('raw mode >', () {
      test('probe enables/disables raw mode', () async {
        final eventController = StreamController<Event>.broadcast();
        final termOsMock = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final term = TermLib();

            await probeTerminal(term, timeout: 1);

            expect(termOsMock.callStack, contains('enableRawMode'));
            expect(termOsMock.callStack, contains('disableRawMode'));

            await term.dispose();
          },
          stdout: MockStdout(),
          stdin: MockStdin(streamString('')),
          termOs: termOsMock,
          hasTerminal: true,
          eventStream: eventController,
        );

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
      expect(ProbeQuery.values, hasLength(10));
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
  });
}
