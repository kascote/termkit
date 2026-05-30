import 'dart:typed_data';

import 'package:test/test.dart';

import 'harness.dart';

void main() {
  group('harness smoke', () {
    test('runOnce on empty input → ok, no events', () {
      final outcome = runOnce(Uint8List(0), const FuzzSchedule([], []));
      expect(outcome, isA<FuzzOk>());
      expect((outcome as FuzzOk).eventCount, 0);
    });

    test('runOnce on `hi` prints two char events', () {
      final outcome = runOnce(
        Uint8List.fromList('hi'.codeUnits),
        FuzzSchedule.single(2),
      );
      expect(outcome, isA<FuzzOk>());
      expect((outcome as FuzzOk).eventCount, 2);
    });

    test('runOnce on complete CSI cursor-position returns event + ground state',
        () {
      // ESC [ 20 ; 10 R
      final bytes = Uint8List.fromList(
        [0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52],
      );
      final outcome = runOnce(bytes, FuzzSchedule.single(bytes.length));
      expect(outcome, isA<FuzzOk>());
      expect((outcome as FuzzOk).eventCount, greaterThanOrEqualTo(1));
    });

    test('runOnceIsolated completes with timeout cleanup', () async {
      final outcome = await runOnceIsolated(
        Uint8List.fromList('ok'.codeUnits),
        FuzzSchedule.single(2),
      );
      expect(outcome, isA<FuzzOk>());
    });
  });
}
