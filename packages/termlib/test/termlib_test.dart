import 'dart:async';
import 'dart:convert';

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import './shared.dart';
import './termlib_mock.dart';

void main() {
  group('Term tests >', () {
    test('hasOutputTerminal should return true if stdout is attached to a TTY', () async {
      await mockedTest((term, _, _) {
        expect(term.hasOutputTerminal, isTrue);
      });
    });

    test('hasOutputTerminal should return false if stdout is not attached to a TTY', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.hasOutputTerminal, isFalse);
        },
        stdout: BufferTermSink(hasTerminal: false),
      );
    });

    test('foregroundColor should return the foreground color', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.foregroundColor, Color.fromRGBComponent(0xc7, 0xc7, 0xc7));
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(r'π]10;rgb:c7f1/c7f1/c7f1π\\'),
      );
    });

    test('foregroundColor must try to parse COLORFGBG if is set and is unable to determine color', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.foregroundColor, Color.ansi(9));
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(''),
        env: {'COLORFGBG': '9;0'},
      );
    });

    test('foregroundColor must return null if unable to determine the color', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.foregroundColor, null);
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(''),
      );
    });

    test('foregroundColor must return null if unable to parse COLORFGBG', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.foregroundColor, null);
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(''),
        env: {'COLORFGBG': 'bananas'},
      );
    });

    test('backgroundColor should return the background color', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.backgroundColor, Color.fromRGBComponent(0xab, 0xcd, 0xef));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(r'π]11;rgb:abf1/cdf1/eff1π\\'),
      );
    });

    test('backgroundColor should return the background based on environment', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.backgroundColor, Color.ansi(11));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        env: {'COLORFGBG': '7;11'},
        stdin: streamString('bananas'),
      );
    });

    test('backgroundColor should return null if is unable to resolve it', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.backgroundColor, null);
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString('bananas'),
      );
    });

    test('enableRawMode must call enableRawMode on TermOs', () async {
      await mockedTest((term, _, tos) {
        term.enableRawMode();
        expect(tos.callStack[0], 'enableRawMode');
      });
    });

    test('disableRawMode must call disableRawMode on TermOs', () async {
      await mockedTest((term, _, tos) {
        term.disableRawMode();
        expect(tos.callStack[0], 'disableRawMode');
      });
    });

    test('style must return a new Style with the terminal profile setup', () async {
      await mockedTest(
        (term, _, _) {
          final style = term.style();
          expect(style, isA<Style>());
          expect(style.profile, ProfileEnum.ansi16);
        },
        profile: ProfileEnum.ansi16,
      );
    });

    test('newLine must return the correct sequence depending on the rawMode setup', () async {
      await mockedTest((term, _, _) {
        expect(term.newLine, '\n');
        term.enableRawMode();
        expect(term.newLine, '\r\n');
        term.disableRawMode();
        expect(term.newLine, '\n');
      });
    });

    test('write must send the object to the stdout', () async {
      await mockedTest((term, out, _) {
        term.write('hello world');
        expect(out.output, 'hello world');
      });
    });

    test('writeLn must send the object to the stdout followed by a new line', () async {
      await mockedTest((term, out, _) {
        term.writeln('hello world');
        expect(out.output, 'hello world\n');

        out.clearOutput();
        term
          ..enableRawMode()
          ..writeln('hello world');
        expect(out.output, 'hello world\r\n');
      });
    });

    test('flush forwards to the backend sink without closing or writing', () async {
      final sink = FlushTrackingBufferSink();
      await mockedTest((term, out, _) async {
        term.write('pending');
        await term.flush();
        expect(sink.flushCount, 1);
        expect(out.output, 'pending');
      }, stdout: sink);
    });

    test('flush is a no-op on BufferTermSink', () async {
      await mockedTest((term, out, _) async {
        await term.flush();
        expect(out.output, isEmpty);
      });
    });

    test('flush does not close the sink; write remains legal afterwards', () async {
      await mockedTest((term, out, _) async {
        await term.flush();
        term.write('after flush');
        expect(out.output, 'after flush');
      });
    });

    test('TermSink.io forwards flush to the underlying Stdout', () async {
      final stdout = FlushTrackingStdout();
      final sink = TermSink.io(stdout);
      await sink.flush();
      expect(stdout.flushCount, 1);
    });

    test('writeAt must write the text at the expected position', () async {
      await mockedTest((term, out, _) {
        term.writeAt(10, 11, 'hello world');
        expect(out.output, '\x1B[10;11Hhello world');
      });
    });

    test('isBackgroundDark check the dark threshold', () async {
      await mockedTest(
        (term, out, tos) async {
          expect(await term.isBackgroundDark(), false);
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(r'π]10;rgb:abf1/cdf1/eff1π\\'),
      );
    });

    test('cursorPosition return cursor position on screen', () async {
      await mockedTest(
        (term, out, tos) async {
          final pos = await term.cursorPosition;
          expect(pos, (row: 10, col: 11));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString(r'π[10;11Rπ\\'),
      );
    });

    test('envNoColor must return true if NO_COLOR is set', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envNoColor(), isTrue);
        },
        env: {'NO_COLOR': 'anything'},
      );
    });

    test('envNoColor must return false if CLICOLOR is set', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envNoColor(), isFalse);
        },
        env: {'CLICOLOR': 'anything'},
      );
    });

    test('envNoColor must return false CLICOLOR_FORCE is set', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envNoColor(), isFalse);
        },
        env: {'CLICOLOR_FORCE': 'anything'},
      );
    });

    test('envNoColor must return true if terminal is not interactive', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envNoColor(), isTrue);
        },
        stdout: BufferTermSink(hasTerminal: false),
      );
    });

    test('envColorProfile must return noColor if NO_COLOR is set', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envColorProfile(), ProfileEnum.noColor);
        },
        env: {'NO_COLOR': 'anything'},
      );
    });

    test('envColorProfile must return ansi16 can no detect from ENV but is forced', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envColorProfile(), ProfileEnum.ansi16);
        },
        env: {'CLICOLOR_FORCE': 'anything'},
      );
    });

    test('envColorProfile must return noColor if terminal is not interactive', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envColorProfile(), ProfileEnum.noColor);
        },
        stdout: BufferTermSink(hasTerminal: false),
      );
    });

    test('envColorProfile must return noColor if unable to detect from environment', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envColorProfile(), ProfileEnum.noColor);
        },
      );
    });

    test('envColorProfile must return trueColor GOOGLE_CLOUD_SHELL is set to true', () async {
      await mockedTest(
        (term, _, _) {
          expect(term.envColorProfile(), ProfileEnum.trueColor);
        },
        env: {'GOOGLE_CLOUD_SHELL': 'true'},
      );
    });

    test('envColorProfile must return trueColor for supported COLORTERM', () async {
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'COLORTERM': 'truecolor'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'COLORTERM': '24bit'},
      );
    });

    test('envColorProfile must return ansi256 for supported COLORTERM', () async {
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi256),
        env: {'COLORTERM': '256color'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi256),
        env: {'COLORTERM': 'yes'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi256),
        env: {'COLORTERM': 'true'},
      );
    });

    test('envColorProfile must return color for supported TERM', () async {
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'kitty'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'xterm-kitty'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'wezterm'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'alacritty'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'contour'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi16),
        env: {'TERM': 'linux'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi256),
        env: {'TERM': 'banana-256color'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi16),
        env: {'TERM': 'banana-color'},
      );
      await mockedTest(
        (term, _, _) => expect(term.envColorProfile(), ProfileEnum.ansi16),
        env: {'TERM': 'banana-ansi'},
      );
    });

    test('terminalColumns must return 80 if the terminal is not interactive', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalColumns, 80),
        stdout: BufferTermSink(hasTerminal: false),
      );
    });

    test('terminalColumns must honor COLUMNS env variables if set and is not interactive', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalColumns, 222),
        stdout: BufferTermSink(columns: 999, hasTerminal: false),
        env: {'COLUMNS': '222'},
      );
    });

    test('terminalColumns must honor COLUMNS env variables if set and is interactive', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalColumns, 221),
        stdout: BufferTermSink(columns: 999),
        env: {'COLUMNS': '221'},
      );
    });

    test('terminalColumns must return the terminal columns', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalColumns, 999),
        stdout: BufferTermSink(columns: 999),
      );
    });

    test('terminalColumns must return default value if terminalColumns is 0', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalColumns, 80),
        stdout: BufferTermSink(columns: 0),
      );
    });

    test('terminalLines must return 25 if the terminal is not interactive', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalLines, 25),
        stdout: BufferTermSink(hasTerminal: false),
      );
    });

    test('terminalLines must honor LINES env variable if set and is not interactive', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalLines, 222),
        stdout: BufferTermSink(rows: 999, hasTerminal: false),
        env: {'LINES': '222'},
      );
    });

    test('terminalLines must honor LINES env variables if set and is interactive', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalLines, 221),
        stdout: BufferTermSink(rows: 999),
        env: {'LINES': '221'},
      );
    });

    test('terminalLines must return the terminal lines', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalLines, 999),
        stdout: BufferTermSink(rows: 999),
      );
    });

    test('terminalLines must return default value if terminalColumns is 0', () async {
      await mockedTest(
        (term, _, _) => expect(term.terminalLines, 25),
        stdout: BufferTermSink(rows: 0),
      );
    });

    test('withModes(rawMode: true) must enable/disable raw mode while executing the callback', () async {
      var ran = false;
      await mockedTest((term, _, tos) async {
        await term.withModes(() async => ran = true, rawMode: true);
        expect(tos.callStack[0], 'enableRawMode');
        expect(tos.callStack[1], 'disableRawMode');
        expect(ran, true);
      });
    });

    test('queryKeyboardCapabilities must return event with data', () async {
      await mockedTest(
        (term, out, tos) async {
          final caps = await term.queryKeyboardCapabilities();
          expect(caps, isA<KeyboardEnhancementFlagsEvent>());
          expect(out.output, '\x1B[?u');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString('π[?0u'),
      );
    });

    test('setKeyboardFlags must send the flag to the terminal', () async {
      await mockedTest((term, out, _) async {
        term.setKeyboardFlags(const KeyboardEnhancementFlagsEvent(1));
        expect(out.output, '\x1B[=1;1u');
      });
    });

    test('pushKeyboardFlags must send the flag to the terminal', () async {
      await mockedTest((term, out, _) async {
        term.pushKeyboardFlags(const KeyboardEnhancementFlagsEvent(3));
        expect(out.output, '\x1B[>3u');
      });
    });

    test('enableKeyboardEnhancement must send base modes', () async {
      await mockedTest((term, out, _) async {
        term.enableKeyboardEnhancement();
        expect(out.output, '\x1B[=15;1u');
      });
    });

    test('enableKeyboardEnhancementFull must send all modes', () async {
      await mockedTest((term, out, _) async {
        term.enableKeyboardEnhancementFull();
        expect(out.output, '\x1B[=31;1u');
      });
    });

    test('disableKeyboardEnhancement must reset the flags', () async {
      await mockedTest((term, out, _) async {
        term.disableKeyboardEnhancement();
        expect(out.output, '\x1B[=0;1u');
      });
    });

    test('popKeyboardFlags must send the command to pop N flags', () async {
      await mockedTest((term, out, _) async {
        term.popKeyboardFlags(3);
        expect(out.output, '\x1B[<3u');
      });
    });

    test('nextEvent() must block until event arrives', () async {
      final controller = StreamController<List<int>>.broadcast();
      await mockedTest(
        (term, out, tos) async {
          var eventReceived = false;
          final readFuture = term.nextEvent<KeyEvent>().then((event) {
            eventReceived = true;
            expect(event.code.char, 'a');
          });

          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(eventReceived, isFalse);

          controller.add(utf8.encode('a'));

          await readFuture;
          expect(eventReceived, isTrue);

          await term.dispose();
          await controller.close();
        },
        stdin: controller.stream,
      );
    });

    test('nextEvent() with type filter must wait for matching event type', () async {
      await mockedTest(
        (term, out, tos) async {
          final readFuture = term.nextEvent<KeyEvent>();

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final event = await readFuture;
          expect(event.code.char, 'x');

          await term.dispose();
        },
        stdin: streamString('x'),
      );
    });

    test('tryEvent() returns null when queue is empty', () async {
      await mockedTest(
        (term, out, tos) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final event = term.tryEvent<KeyEvent>();
          expect(event, isNull);

          await term.dispose();
        },
        stdin: streamString(''),
      );
    });

    test('dispose() must cancel subscription and clear queue', () async {
      await mockedTest(
        (term, _, _) async {
          await term.dispose();
          expect(() => term.tryEvent<KeyEvent>(), throwsA(isA<TypeError>()));
        },
        stdin: streamString('abc'),
      );
    });

    test('backend: eventQueue injection seeds events', () async {
      final queue = EventQueue();
      injectEvent(queue, const KeyEvent(KeyCode.char('a')));
      injectEvent(queue, const KeyEvent(KeyCode.char('b')));

      await mockedTest(
        (term, _, _) async {
          final event1 = term.tryEvent<KeyEvent>();
          expect(event1?.code.char, 'a');

          final event2 = term.tryEvent<KeyEvent>();
          expect(event2?.code.char, 'b');

          final event3 = term.tryEvent<KeyEvent>();
          expect(event3, isNull);

          await term.dispose();
        },
        eventQueue: queue,
      );
    });

    test('backend: eventSource injection feeds events into queue', () async {
      final controller = createEventController();

      await mockedTest(
        (term, _, _) async {
          controller
            ..add(const KeyEvent(KeyCode.char('x')))
            ..add(const KeyEvent(KeyCode.char('y')));

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final event1 = term.tryEvent<KeyEvent>();
          expect(event1?.code.char, 'x');

          final event2 = term.tryEvent<KeyEvent>();
          expect(event2?.code.char, 'y');

          await term.dispose();
          await controller.close();
        },
        eventSource: controller.stream,
      );
    });

    test('Term.open returns PipedTerm when !hasTerminal, InteractiveTerm when tty', () async {
      await mockedPipedTest((term, _, _) {
        expect(term, isA<PipedTerm>());
        expect(term.hasTerminal, isFalse);
      });

      await mockedTest(
        (term, _, _) async {
          expect(term, isA<InteractiveTerm>());
          expect(term.hasTerminal, isTrue);
          await term.dispose();
        },
      );
    });

    test('concurrent tryEvent() calls must consume events independently', () async {
      final queue = EventQueue();
      injectEvent(queue, const KeyEvent(KeyCode.char('a')));
      injectEvent(queue, const KeyEvent(KeyCode.char('b')));
      injectEvent(queue, const KeyEvent(KeyCode.char('c')));
      injectEvent(queue, const MouseEvent(10, 20, MouseButton(MouseButtonKind.left, MouseButtonAction.down)));
      injectEvent(queue, const KeyEvent(KeyCode.char('d')));

      await mockedTest(
        (term, _, _) async {
          expect(term.tryEvent<KeyEvent>()?.code.char, 'a');
          expect(term.tryEvent<KeyEvent>()?.code.char, 'b');

          final mouse = term.tryEvent<MouseEvent>();
          expect(mouse?.x, 10);
          expect(mouse?.y, 20);

          expect(term.tryEvent<KeyEvent>()?.code.char, 'c');
          expect(term.tryEvent<KeyEvent>()?.code.char, 'd');
          expect(term.tryEvent<KeyEvent>(), isNull);

          await term.dispose();
        },
        eventQueue: queue,
      );
    });

    test('concurrent tryEvent() with type filtering must skip non-matching events', () async {
      final queue = EventQueue();
      injectEvent(queue, const MouseEvent(1, 1, MouseButton(MouseButtonKind.left, MouseButtonAction.down)));
      injectEvent(queue, const MouseEvent(2, 2, MouseButton(MouseButtonKind.right, MouseButtonAction.up)));
      injectEvent(queue, const KeyEvent(KeyCode.char('x')));
      injectEvent(queue, const MouseEvent(3, 3, MouseButton(MouseButtonKind.middle, MouseButtonAction.down)));
      injectEvent(queue, const KeyEvent(KeyCode.char('y')));

      await mockedTest(
        (term, _, _) async {
          expect(term.tryEvent<KeyEvent>()?.code.char, 'x');
          expect(term.tryEvent<KeyEvent>()?.code.char, 'y');
          expect(term.tryEvent<KeyEvent>(), isNull);

          expect(term.tryEvent<MouseEvent>()?.x, 1);
          expect(term.tryEvent<MouseEvent>()?.x, 2);
          expect(term.tryEvent<MouseEvent>()?.x, 3);
          expect(term.tryEvent<Event>(), isNull);

          await term.dispose();
        },
        eventQueue: queue,
      );
    });

    test('concurrent tryEvent() and nextEvent() can be mixed', () async {
      final controller = createEventController();

      await mockedTest(
        (term, _, _) async {
          controller
            ..add(const KeyEvent(KeyCode.char('a')))
            ..add(const KeyEvent(KeyCode.char('b')));

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(term.tryEvent<KeyEvent>()?.code.char, 'a');

          final read1 = await term.nextEvent<KeyEvent>();
          expect(read1.code.char, 'b');

          expect(term.tryEvent<KeyEvent>(), isNull);

          controller.add(const KeyEvent(KeyCode.char('c')));
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final read2 = await term.nextEvent<KeyEvent>();
          expect(read2.code.char, 'c');

          await term.dispose();
          await controller.close();
        },
        eventSource: controller.stream,
      );
    });

    test('events stream emits parsed events', () async {
      final controller = createEventController();

      await mockedTest(
        (term, _, _) async {
          final received = <Event>[];
          final subscription = term.events.listen(received.add);

          controller
            ..add(const KeyEvent(KeyCode.char('x')))
            ..add(const KeyEvent(KeyCode.char('y')));

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(received, hasLength(2));
          expect(received[0], isA<KeyEvent>());
          expect((received[0] as KeyEvent).code.char, 'x');
          expect(received[1], isA<KeyEvent>());
          expect((received[1] as KeyEvent).code.char, 'y');

          await subscription.cancel();
          await term.dispose();
          await controller.close();
        },
        eventSource: controller.stream,
      );
    });

    test('events stream supports multiple subscribers', () async {
      final controller = createEventController();

      await mockedTest(
        (term, _, _) async {
          final received1 = <Event>[];
          final received2 = <Event>[];

          final sub1 = term.events.listen(received1.add);
          final sub2 = term.events.listen(received2.add);

          controller.add(const KeyEvent(KeyCode.char('z')));

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(received1, hasLength(1));
          expect(received2, hasLength(1));
          expect((received1[0] as KeyEvent).code.char, 'z');
          expect((received2[0] as KeyEvent).code.char, 'z');

          await sub1.cancel();
          await sub2.cancel();
          await term.dispose();
          await controller.close();
        },
        eventSource: controller.stream,
      );
    });

    test('PipedTerm has no events member (compile-time check)', () async {
      // Sealed split replaces the runtime StateError with a compile-time guard.
      // The only way to observe the split at runtime is via `is`/pattern-match.
      await mockedPipedTest((term, _, _) {
        expect(term, isA<PipedTerm>());
        // `term.events` would be a static error — not expressible at runtime.
      });
    });

    test('events stream coexists with tryEvent/nextEvent', () async {
      final controller = createEventController();

      await mockedTest(
        (term, _, _) async {
          final streamEvents = <Event>[];
          final subscription = term.events.listen(streamEvents.add);

          controller
            ..add(const KeyEvent(KeyCode.char('a')))
            ..add(const KeyEvent(KeyCode.char('b')))
            ..add(const KeyEvent(KeyCode.char('c')));

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(streamEvents, hasLength(3));

          expect(term.tryEvent<KeyEvent>()?.code.char, 'a');
          expect(term.tryEvent<KeyEvent>()?.code.char, 'b');
          expect(term.tryEvent<KeyEvent>()?.code.char, 'c');

          await subscription.cancel();
          await term.dispose();
          await controller.close();
        },
        eventSource: controller.stream,
      );
    });
  });
}
