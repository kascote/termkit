import 'dart:async';
import 'dart:io' show File, Process;

// The type annotations on local vars are intentional — they document the
// static return types that Phase 2 promises.
// ignore_for_file: omit_local_variable_types

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 2 API shape', () {
    group('return types', () {
      test('tryEvent<KeyEvent>() returns KeyEvent?', () async {
        // Static check: the declared return type is `KeyEvent?`, not `Event`.
        // Previously poll<KeyEvent>() returned Event with a NoneEvent sentinel.
        final queue = EventQueue()..enqueue(KeyEvent.fromString('a'));
        final term =
            Term.open(
                  backend: TermBackend.fake(eventQueue: queue),
                )
                as InteractiveTerm;

        final KeyEvent? event = term.tryEvent<KeyEvent>();
        expect(event, isA<KeyEvent?>());
        expect(event?.code.char, 'a');

        final KeyEvent? none = term.tryEvent<KeyEvent>();
        expect(none, isNull);

        await term.dispose();
      });

      test('awaitEvent<KeyEvent>() returns Future<KeyEvent?>', () async {
        final term =
            Term.open(
                  backend: TermBackend.fake(eventQueue: EventQueue()),
                )
                as InteractiveTerm;

        final Future<KeyEvent?> fut = term.awaitEvent<KeyEvent>(
          timeout: const Duration(milliseconds: 10),
        );
        final KeyEvent? event = await fut;
        expect(event, isNull);

        await term.dispose();
      });

      test('nextEvent<KeyEvent>() returns Future<KeyEvent> (non-null)', () async {
        final queue = EventQueue()..enqueue(KeyEvent.fromString('z'));
        final term =
            Term.open(
                  backend: TermBackend.fake(eventQueue: queue),
                )
                as InteractiveTerm;

        final Future<KeyEvent> fut = term.nextEvent<KeyEvent>();
        final KeyEvent event = await fut;
        expect(event.code.char, 'z');

        await term.dispose();
      });
    });

    group('sealed split', () {
      test('Term.open returns InteractiveTerm when hasTerminal == true', () {
        final backend = TermBackend.fake();
        final term = Term.open(backend: backend);
        expect(term, isA<InteractiveTerm>());
        expect(term, isNot(isA<PipedTerm>()));
        switch (term) {
          case InteractiveTerm():
            expect(term.hasTerminal, isTrue);
          case PipedTerm():
            fail('expected InteractiveTerm, got PipedTerm');
        }
      });

      test('Term.open returns PipedTerm when hasTerminal == false', () {
        final backend = TermBackend.fake(hasTerminal: false);
        final term = Term.open(backend: backend);
        expect(term, isA<PipedTerm>());
        expect(term, isNot(isA<InteractiveTerm>()));
        switch (term) {
          case InteractiveTerm():
            fail('expected PipedTerm, got InteractiveTerm');
          case PipedTerm():
            expect(term.hasTerminal, isFalse);
        }
      });

      test('sealed hierarchy: switch exhausts with just the two subtypes', () {
        // Verifying by construction — if a new sibling were added without
        // updating call sites, this switch would stop being exhaustive and
        // the analyzer would complain. This test passing means the split is
        // wired.
        final tA = Term.open(backend: TermBackend.fake());
        final tB = Term.open(backend: TermBackend.fake(hasTerminal: false));
        String tag(Term t) => switch (t) {
          InteractiveTerm() => 'interactive',
          PipedTerm() => 'piped',
        };
        expect(tag(tA), 'interactive');
        expect(tag(tB), 'piped');
      });
    });

    group('compile-time API partitioning', () {
      // Runtime proxies for the static guarantee. The sealed split means:
      //   - stdinBytes only exists on PipedTerm
      //   - events / tryEvent / nextEvent / awaitEvent only exist on
      //     InteractiveTerm
      // There is no runtime-visible way to prove the compile-time side;
      // instead we run `dart analyze` against a fixture file that attempts
      // both misuses and assert it reports errors.

      test('stdinBytes on InteractiveTerm is a static error', () async {
        // The fixture imports termlib, builds an InteractiveTerm, and
        // accesses `.stdinBytes` — which must fail analysis. It also
        // accesses `events`/`tryEvent`/`nextEvent`/`awaitEvent` on a
        // PipedTerm, which must also fail. `dart analyze` must exit non-zero.
        const fixture = '''
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

void onInteractive(InteractiveTerm t) {
  // stdinBytes is only on PipedTerm — this must be a static error.
  // ignore: avoid_print
  print(t.stdinBytes);
}

void onPiped(PipedTerm t) {
  // events, tryEvent, nextEvent, awaitEvent only on InteractiveTerm.
  // ignore: avoid_print
  print(t.events);
  t.tryEvent<KeyEvent>();
  t.nextEvent<KeyEvent>();
  t.awaitEvent<KeyEvent>();
}

void main() {}
''';
        // Place the fixture inside the package so package:termlib/... URIs
        // resolve via this package's pubspec. Clean it up afterwards.
        final file = File('test/fixtures/phase2_static_misuse.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync(fixture);
        try {
          final proc = await Process.run(
            'dart',
            ['analyze', file.path],
          );
          expect(
            proc.exitCode,
            isNot(equals(0)),
            reason: 'fixture expected to fail analysis. stdout=${proc.stdout} stderr=${proc.stderr}',
          );
          final out = '${proc.stdout}\n${proc.stderr}';
          // Each misuse must be reported as undefined_getter/method.
          expect(out, contains("getter 'stdinBytes' isn't defined"));
          expect(out, contains("getter 'events' isn't defined"));
          expect(out, contains("method 'tryEvent' isn't defined"));
          expect(out, contains("method 'nextEvent' isn't defined"));
          expect(out, contains("method 'awaitEvent' isn't defined"));
        } finally {
          if (file.existsSync()) file.deleteSync();
          final dir = file.parent;
          if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
        }
      }, timeout: const Timeout(Duration(minutes: 1)));
    });
  });
}
