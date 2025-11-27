import 'dart:async';
import 'dart:io';

import 'package:termlib/src/shared/terminal_overrides.dart';
import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'shared.dart';
import 'termlib_mock.dart';

void main() {
  group('TermRunner', () {
    group('build()', () {
      test('creates TermLib with default settings', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner();
            final term = setup.build();

            expect(stdout.output, isEmpty);
            expect(termOs.callStack, isEmpty);

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('enables alternate screen', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(alternateScreen: true);
            final term = setup.build();

            expect(stdout.output, contains('\x1B[?1049h'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('enables raw mode', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(rawMode: true);
            final term = setup.build();

            expect(termOs.callStack, contains('enableRawMode'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('hides cursor', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(hideCursor: true);
            final term = setup.build();

            expect(stdout.output, contains('\x1B[?25l'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('enables mouse events', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(mouseEvents: true);
            final term = setup.build();

            expect(stdout.output, contains('\x1B[?1000;1003;1006h'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('sets terminal title', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(title: 'Test App');
            final term = setup.build();

            expect(stdout.output, contains('\x1B]0;Test App\x07'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('enables keyboard enhancement', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(keyboardEnhancement: true);
            final term = setup.build();

            // Kitty keyboard protocol: CSI = flags ; mode u
            expect(stdout.output, contains('\x1B[='));
            expect(stdout.output, contains('u'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('applies all options together', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              alternateScreen: true,
              rawMode: true,
              hideCursor: true,
              mouseEvents: true,
              keyboardEnhancement: true,
              title: 'Full App',
            );
            final term = setup.build();

            expect(stdout.output, contains('\x1B[?1049h'));
            expect(stdout.output, contains('\x1B[?25l'));
            expect(stdout.output, contains('\x1B[?1000;1003;1006h'));
            expect(stdout.output, contains('\x1B[=')); // keyboard enhancement
            expect(stdout.output, contains('\x1B]0;Full App\x07'));
            expect(termOs.callStack, contains('enableRawMode'));

            await term.dispose();
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });
    });

    group('run()', () {
      test('returns exit code from function', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        int? capturedExitCode;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              exitCallback: (term, code) async {
                capturedExitCode = code;
              },
            );

            final result = await setup.run((term) async => 42);

            expect(result, equals(42));
            expect(capturedExitCode, equals(42));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('handles sync function', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        int? capturedExitCode;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              exitCallback: (term, code) async {
                capturedExitCode = code;
              },
            );

            final result = await setup.run((term) => 0);

            expect(result, equals(0));
            expect(capturedExitCode, equals(0));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('restores terminal on success', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              alternateScreen: true,
              rawMode: true,
              hideCursor: true,
              mouseEvents: true,
              exitCallback: (term, code) async {},
            );

            await setup.run((term) async => 0);

            // Check restore sequence in output
            expect(stdout.output, contains('\x1B[?1000;1003;1006l')); // disable mouse
            expect(stdout.output, contains('\x1B[?25h')); // show cursor
            expect(stdout.output, contains('\x1B[?1049l')); // disable alt screen
            expect(termOs.callStack, contains('disableRawMode'));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('handles error and returns default error code', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        int? capturedExitCode;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              showError: false,
              exitCallback: (term, code) async {
                capturedExitCode = code;
              },
            );

            final result = await setup.run((term) async {
              throw Exception('Test error');
            });

            expect(result, equals(1)); // default error code
            expect(capturedExitCode, equals(1));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('uses custom default error code', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        int? capturedExitCode;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              defaultErrorCode: 99,
              showError: false,
              exitCallback: (term, code) async {
                capturedExitCode = code;
              },
            );

            final result = await setup.run((term) async {
              throw Exception('Test error');
            });

            expect(result, equals(99));
            expect(capturedExitCode, equals(99));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('calls onError handler and uses its return value', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        Object? capturedError;
        int? capturedExitCode;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              showError: false,
              onError: (term, error, stack) {
                capturedError = error;
                return 77;
              },
              exitCallback: (term, code) async {
                capturedExitCode = code;
              },
            );

            final result = await setup.run((term) async {
              throw Exception('Custom error');
            });

            expect(result, equals(77));
            expect(capturedExitCode, equals(77));
            expect(capturedError.toString(), contains('Custom error'));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('restores terminal before calling onError', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        var wasTerminalRestored = false;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              rawMode: true,
              showError: false,
              onError: (term, error, stack) {
                wasTerminalRestored = termOs.callStack.contains('disableRawMode');
                return 1;
              },
              exitCallback: (term, code) async {},
            );

            await setup.run((term) async {
              throw Exception('error');
            });

            expect(wasTerminalRestored, isTrue);
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('onError can be async', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        int? capturedExitCode;

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              showError: false,
              onError: (term, error, stack) async {
                await Future<void>.delayed(Duration.zero);
                return 55;
              },
              exitCallback: (term, code) async {
                capturedExitCode = code;
              },
            );

            final result = await setup.run((term) async {
              throw Exception('async error');
            });

            expect(result, equals(55));
            expect(capturedExitCode, equals(55));
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });
    });

    group('configuration', () {
      test('showError=true does not suppress errors', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        final stderrOutput = StringBuffer();

        // Capture stderr to avoid noisy test output
        await IOOverrides.runZoned(
          () async {
            await TerminalOverrides.runZoned(
              () async {
                final setup = TermRunner(
                  exitCallback: (term, code) async {},
                );

                // Should complete without throwing, error is written to stderr
                final result = await setup.run((term) async {
                  throw Exception('Visible error');
                });

                expect(result, equals(1)); // default error code
              },
              stdout: stdout,
              stdin: stdin,
              termOs: termOs,
              hasTerminal: false,
            );
          },
          stderr: () => MockStderr(stderrOutput),
        );

        // Verify error was written to stderr
        expect(stderrOutput.toString(), contains('Visible error'));
      });

      test('showError=false suppresses error output', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();

        await TerminalOverrides.runZoned(
          () async {
            final setup = TermRunner(
              showError: false,
              exitCallback: (term, code) async {},
            );

            // Should not throw and output should be clean
            await setup.run((term) async {
              throw Exception('Silent error');
            });
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );

        // stdout should only have terminal setup, no error output
        expect(stdout.output, isNot(contains('Silent error')));
      });
    });

    group('onCleanup', () {
      test('is called on normal exit', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        var cleanupCalled = false;

        await TerminalOverrides.runZoned(
          () async {
            final runner = TermRunner(
              onCleanup: (term) async {
                cleanupCalled = true;
              },
              exitCallback: (term, code) async {},
            );

            await runner.run((term) async => 0);

            expect(cleanupCalled, isTrue);
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('is called on error', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        var cleanupCalled = false;

        await TerminalOverrides.runZoned(
          () async {
            final runner = TermRunner(
              showError: false,
              onCleanup: (term) async {
                cleanupCalled = true;
              },
              exitCallback: (term, code) async {},
            );

            await runner.run((term) async {
              throw Exception('error');
            });

            expect(cleanupCalled, isTrue);
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });

      test('is called after terminal restored', () async {
        final stdout = MockStdout();
        final stdin = MockStdin(streamString(''));
        final termOs = TermOsMock();
        var wasTerminalRestored = false;

        await TerminalOverrides.runZoned(
          () async {
            final runner = TermRunner(
              rawMode: true,
              onCleanup: (term) async {
                wasTerminalRestored = termOs.callStack.contains('disableRawMode');
              },
              exitCallback: (term, code) async {},
            );

            await runner.run((term) async => 0);

            expect(wasTerminalRestored, isTrue);
          },
          stdout: stdout,
          stdin: stdin,
          termOs: termOs,
          hasTerminal: false,
        );
      });
    });
  });
}
