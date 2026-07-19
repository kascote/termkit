/// Acceptance tests for known Engine bugs, written against the DESIRED
/// behaviour and skipped until the fix lands.
///
/// Each skip marker names the tracked task for the bug. The workflow when
/// fixing one:
///
///  1. Fix the engine. The conformance sweep (dec_ansi_conformance_test.dart)
///     will fail on the affected cells, because its `deviations` registry pins
///     the OLD behaviour — update/remove those entries consciously.
///  2. Remove the `skip:` here; the test must go green.
///  3. Close the tracked task.
///
/// While iterating, `dart test --run-skipped test/conformance/` runs these
/// without editing the file.
///
/// The bugs were found by the DEC ANSI conformance sweep against the oracle in
/// specs/dec_ansi/ (vt100.net/emu/dec_ansi_parser).
library;

import 'package:termparser/src/engine/engine.dart';
import 'package:termparser/src/engine/parameters.dart';
import 'package:termparser/src/engine/sequence_data.dart';
import 'package:test/test.dart';

List<SequenceData> feed(Engine engine, List<int> bytes, {bool trailingHasMore = true}) {
  final out = <SequenceData>[];
  for (var i = 0; i < bytes.length; i++) {
    final hasMore = i < bytes.length - 1 || trailingHasMore;
    final r = engine.advance(bytes[i], hasMore: hasMore);
    if (r != null) out.add(r);
  }
  return out;
}

void main() {
  group('pending engine fixes', () {
    test(
      'DCS header: digits accumulate as parameters until a 0x40-0x7E final hooks',
      () {
        // DCS 12;3 q data ST — the DEC machine collects params 12 and 3 in the
        // header and hooks passthrough at the final 'q' (0x71).
        final bytes = [
          0x1B, 0x50, 0x31, 0x32, 0x3B, 0x33, 0x71, // ESC P 1 2 ; 3 q
          ...'data'.codeUnits,
          0x1B, 0x5C, // ST
        ];
        final results = feed(Engine(), bytes, trailingHasMore: false);
        expect(results, hasLength(1));
        final dcs = results.single as DcsSequenceData;
        expect(dcs.params, const Parameters(['12', '3']));
        expect(String.fromCharCodes(dcs.contentBytes), contains('data'));
      },
    );

    test(
      'OSC parameters keep bytes 0x20-0x2E (base64 plus sign in OSC 52 reply)',
      () {
        // OSC 52 clipboard read reply: ESC ] 52 ; c ; a+b= ESC \
        final bytes = [
          0x1B, 0x5D, 0x35, 0x32, 0x3B, 0x63, 0x3B, // ESC ] 5 2 ; c ;
          ...'a+b='.codeUnits,
          0x1B, 0x5C, // ST
        ];
        final results = feed(Engine(), bytes, trailingHasMore: false);
        expect(results, [
          const OscSequenceData(Parameters(['52', 'c', 'a+b='])),
        ]);
      },
    );

    test(
      'parameter byte after CSI intermediate consumes the sequence, no phantom key',
      () {
        // ESC [ 1 SP 2 m is malformed (parameter after intermediate). DEC
        // consumes it through the final 'm' in csi_ignore; nothing may surface
        // as input. A structural ErrorSequenceData is acceptable.
        final results = feed(Engine(), [0x1B, 0x5B, 0x31, 0x20, 0x32, 0x6D], trailingHasMore: false);
        expect(results.whereType<CharData>(), isEmpty);
        expect(results.whereType<CsiSequenceData>(), isEmpty);
      },
    );

    test(
      'CAN cancels an in-flight CSI and is delivered; CAN also cancels OSC strings',
      skip:
          'CAN/SUB are swallowed when cancelling (stored as a '
          'param in csiEntry) and ignored inside DCS/OSC strings',
      () {
        // DEC: CAN cancels the sequence AND executes (the app sees Ctrl+X).
        // If the tracked task decides against delivery, weaken the
        // CharData(0x18) expectations here deliberately.
        expect(
          feed(Engine(), [0x1B, 0x5B, 0x33, 0x18, 0x41], trailingHasMore: false),
          [const CharData('\x18', escO: false), const CharData('A', escO: false)],
        );

        // CAN inside an OSC string cancels it: no OSC dispatch may follow and
        // subsequent bytes are plain input again.
        final osc = feed(Engine(), [0x1B, 0x5D, 0x30, 0x3B, 0x68, 0x18, 0x78], trailingHasMore: false);
        expect(osc.whereType<OscSequenceData>(), isEmpty);
        expect(osc, contains(const CharData('x', escO: false)));
      },
    );
  });
}
