import 'dart:async';

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
  });
}
