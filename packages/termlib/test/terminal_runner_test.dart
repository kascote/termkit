import 'dart:async';
import 'dart:io';

import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'termlib_mock.dart';

/// Build a fake [TermBackend] wired to captured stdout + mock TermOs, then
/// run [fn] with the three pieces exposed.
Future<T> withFakeBackend<T>(
  Future<T> Function(TermBackend backend, BufferTermSink stdout, TermOsMock tos) fn, {
  bool hasTerminal = false,
}) async {
  final stdout = BufferTermSink(hasTerminal: hasTerminal);
  final tos = TermOsMock();
  final backend = TermBackend.fake(stdout: stdout, termOs: tos, hasTerminal: hasTerminal);
  return fn(backend, stdout, tos);
}

void main() {
  group('TermRunner', () {
    group('build()', () {
      test('creates TermLib with default settings', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend);
          final term = setup.build();

          expect(stdout.output, isEmpty);
          expect(termOs.callStack, isEmpty);

          await term.dispose();
        });
      });

      test('enables alternate screen', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend, alternateScreen: true);
          final term = setup.build();

          expect(stdout.output, contains('\x1B[?1049h'));

          await term.dispose();
        });
      });

      test('enables raw mode', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend, rawMode: true);
          final term = setup.build();

          expect(termOs.callStack, contains('enableRawMode'));

          await term.dispose();
        });
      });

      test('hides cursor', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend, hideCursor: true);
          final term = setup.build();

          expect(stdout.output, contains('\x1B[?25l'));

          await term.dispose();
        });
      });

      test('enables mouse events', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend, mouseEvents: true);
          final term = setup.build();

          expect(stdout.output, contains('\x1B[?1000;1003;1006h'));

          await term.dispose();
        });
      });

      test('sets terminal title', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend, title: 'Test App');
          final term = setup.build();

          expect(stdout.output, contains('\x1B]0;Test App\x07'));

          await term.dispose();
        });
      });

      test('enables keyboard enhancement', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(backend: backend, keyboardEnhancement: true);
          final term = setup.build();

          expect(stdout.output, contains('\x1B[='));
          expect(stdout.output, contains('u'));

          await term.dispose();
        });
      });

      test('applies all options together', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
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
          expect(stdout.output, contains('\x1B[='));
          expect(stdout.output, contains('\x1B]0;Full App\x07'));
          expect(termOs.callStack, contains('enableRawMode'));

          await term.dispose();
        });
      });
    });

    group('run()', () {
      test('returns exit code from function', () async {
        int? capturedExitCode;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
            exitCallback: (term, code) async {
              capturedExitCode = code;
            },
          );

          final result = await setup.run((term) async => 42);

          expect(result, equals(42));
          expect(capturedExitCode, equals(42));
        });
      });

      test('handles sync function', () async {
        int? capturedExitCode;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
            exitCallback: (term, code) async {
              capturedExitCode = code;
            },
          );

          final result = await setup.run((term) => 0);

          expect(result, equals(0));
          expect(capturedExitCode, equals(0));
        });
      });

      test('restores terminal on success', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
            alternateScreen: true,
            rawMode: true,
            hideCursor: true,
            mouseEvents: true,
            exitCallback: (term, code) async {},
          );

          await setup.run((term) async => 0);

          expect(stdout.output, contains('\x1B[?1000;1003;1006l'));
          expect(stdout.output, contains('\x1B[?25h'));
          expect(stdout.output, contains('\x1B[?1049l'));
          expect(termOs.callStack, contains('disableRawMode'));
        });
      });

      test('handles error and returns default error code', () async {
        int? capturedExitCode;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
            showError: false,
            exitCallback: (term, code) async {
              capturedExitCode = code;
            },
          );

          final result = await setup.run((term) async {
            throw Exception('Test error');
          });

          expect(result, equals(1));
          expect(capturedExitCode, equals(1));
        });
      });

      test('uses custom default error code', () async {
        int? capturedExitCode;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
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
        });
      });

      test('calls onError handler and uses its return value', () async {
        Object? capturedError;
        int? capturedExitCode;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
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
        });
      });

      test('restores terminal before calling onError', () async {
        var wasTerminalRestored = false;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
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
        });
      });

      test('onError can be async', () async {
        int? capturedExitCode;
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
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
        });
      });
    });

    group('configuration', () {
      test('showError=true does not suppress errors', () async {
        final stderrOutput = StringBuffer();

        await IOOverrides.runZoned(
          () async {
            await withFakeBackend((backend, stdout, termOs) async {
              final setup = TermRunner(
                backend: backend,
                exitCallback: (term, code) async {},
              );

              final result = await setup.run((term) async {
                throw Exception('Visible error');
              });

              expect(result, equals(1));
            });
          },
          stderr: () => MockStderr(stderrOutput),
        );

        expect(stderrOutput.toString(), contains('Visible error'));
      });

      test('showError=false suppresses error output', () async {
        await withFakeBackend((backend, stdout, termOs) async {
          final setup = TermRunner(
            backend: backend,
            showError: false,
            exitCallback: (term, code) async {},
          );

          await setup.run((term) async {
            throw Exception('Silent error');
          });

          expect(stdout.output, isNot(contains('Silent error')));
        });
      });
    });

    group('onCleanup', () {
      test('is called on normal exit', () async {
        var cleanupCalled = false;
        await withFakeBackend((backend, stdout, termOs) async {
          final runner = TermRunner(
            backend: backend,
            onCleanup: (term) async {
              cleanupCalled = true;
            },
            exitCallback: (term, code) async {},
          );

          await runner.run((term) async => 0);

          expect(cleanupCalled, isTrue);
        });
      });

      test('is called on error', () async {
        var cleanupCalled = false;
        await withFakeBackend((backend, stdout, termOs) async {
          final runner = TermRunner(
            backend: backend,
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
        });
      });

      test('is called after terminal restored', () async {
        var wasTerminalRestored = false;
        await withFakeBackend((backend, stdout, termOs) async {
          final runner = TermRunner(
            backend: backend,
            rawMode: true,
            onCleanup: (term) async {
              wasTerminalRestored = termOs.callStack.contains('disableRawMode');
            },
            exitCallback: (term, code) async {},
          );

          await runner.run((term) async => 0);

          expect(wasTerminalRestored, isTrue);
        });
      });
    });
  });
}
