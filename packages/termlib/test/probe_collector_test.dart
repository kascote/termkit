import 'dart:async';

import 'package:termlib/src/probe/probe_collector.dart';
import 'package:termlib/src/probe/term_info.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  // Probe all 11 queries so classification, not the wanted-filter, is exercised.
  ProbeCollector allWanted() => ProbeCollector(ProbeQuery.values.toSet());

  group('ProbeCollector._classify (via offer) >', () {
    test('maps each reply type to its query slot', () {
      final cases = <ProbeQuery, ResponseEvent>{
        ProbeQuery.deviceAttrs: const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, []),
        ProbeQuery.terminalVersion: const NameAndVersionEvent('xterm(1)'),
        ProbeQuery.foregroundColor: const ColorQueryEvent(10, 0xFF, 0x80, 0x40),
        ProbeQuery.backgroundColor: const ColorQueryEvent(11, 0x00, 0x10, 0x20),
        ProbeQuery.syncUpdate: QuerySyncUpdateEvent(1),
        ProbeQuery.keyboardCapabilities: const KeyboardEnhancementFlagsEvent(1),
        ProbeQuery.windowSizePixels: const QueryTerminalWindowSizeEvent(1920, 1080),
        ProbeQuery.unicodeCore: UnicodeCoreEvent(1),
        ProbeQuery.colorScheme: ColorSchemeEvent(1),
        ProbeQuery.inBandResize: QueryWindowResizeEvent(1),
        ProbeQuery.bracketedPaste: QueryBracketedPasteEvent(1),
      };

      for (final entry in cases.entries) {
        final c = allWanted();
        expect(c.offer(entry.value), isTrue, reason: '${entry.key} should be consumed');
        expect(c.results[entry.key], same(entry.value), reason: '${entry.key} slotted by type');
        expect(c.results, hasLength(1), reason: 'only ${entry.key} slotted');
      }
    });

    test('disambiguates fg vs bg ColorQueryEvent by .code', () {
      final c = allWanted();
      const fg = ColorQueryEvent(10, 0xFF, 0x80, 0x40);
      const bg = ColorQueryEvent(11, 0x00, 0x10, 0x20);

      expect(c.offer(fg), isTrue);
      expect(c.offer(bg), isTrue);

      expect(c.results[ProbeQuery.foregroundColor], same(fg));
      expect(c.results[ProbeQuery.backgroundColor], same(bg));
    });

    test('unqueried color code (e.g. 12 cursor) is a stray', () {
      final c = allWanted();
      // OSC 12 (cursor color) maps to no ProbeQuery → not consumed.
      expect(c.offer(const ColorQueryEvent(12, 1, 2, 3)), isFalse);
      expect(c.results, isEmpty);
    });
  });

  group('ProbeCollector.offer >', () {
    test('non-probe event is a stray (not consumed)', () {
      final c = allWanted();
      expect(c.offer(KeyEvent.fromString('a')), isFalse);
      expect(c.results, isEmpty);
    });

    test('reply to an unwanted query is not consumed', () {
      // Only the fence is wanted; a version reply must fall through to the queue.
      final c = ProbeCollector({ProbeQuery.deviceAttrs});
      expect(c.offer(const NameAndVersionEvent('xterm(1)')), isFalse);
      expect(c.results, isEmpty);
    });

    test('duplicate reply for a filled slot is consumed but ignored', () {
      final c = allWanted();
      final first = QuerySyncUpdateEvent(1);
      final second = QuerySyncUpdateEvent(2);

      expect(c.offer(first), isTrue);
      expect(c.offer(second), isTrue, reason: 'dup is still consumed');
      expect(c.results[ProbeQuery.syncUpdate], same(first), reason: 'first wins');
    });
  });

  group('ProbeCollector fence (done) >', () {
    test('completes when DA1 arrives, not before', () async {
      final c = allWanted();
      var completed = false;
      unawaited(c.done.then((_) => completed = true));

      // A non-fence reply must not complete the fence.
      c.offer(QuerySyncUpdateEvent(1));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      c.offer(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, []));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isTrue);
    });

    test('fence is wanted even when deviceAttrs is "skipped" by the caller', () async {
      // Caller passes a set without deviceAttrs; the ctor adds it back.
      final c = ProbeCollector({ProbeQuery.foregroundColor});
      expect(c.wanted, contains(ProbeQuery.deviceAttrs));

      expect(c.offer(const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, [])), isTrue);
      await c.done; // resolves → fence fired
    });

    test('duplicate DA1 does not re-complete (no throw)', () async {
      final c = allWanted();
      const da1 = PrimaryDeviceAttributesEvent(DeviceAttributeType.vt220, []);

      expect(c.offer(da1), isTrue);
      expect(c.offer(da1), isTrue, reason: 'second DA1 consumed without re-completing');
      await c.done;
    });
  });
}
