import 'dart:async';
import 'dart:io';

import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import './shared.dart';

typedef Theme = ({
  Style aqua,
  Style indianRed,
  Style darkCyan,
  Style magenta,
  Style webGray,
  Style error,
});

Future<void> main(List<String> arguments) async {
  final t = TermLib();
  final withKitty = arguments.contains('-kitty');

  if (withKitty) t.enableKeyboardEnhancement();

  ProcessSignal.sigterm.watch().listen((event) {
    t
      ..writeln('SIGTERM received')
      ..disableKeyboardEnhancement()
      ..disableMouseEvents()
      ..disableRawMode()
      ..flushThenExit(0);
  });

  await t.withRawModeAsync(() => keyViewer(t, withKitty: withKitty));
  await t.flushThenExit(0);
}

Future<void> keyViewer(TermLib t, {bool withKitty = false}) async {
  final cycle = Cycle(['|', '/', '-', r'\']);
  final tick = Timer.periodic(const Duration(milliseconds: 100), (timer) => timer.tick);

  t
    ..eraseClear()
    ..writeln(' ')
    ..writeln(' ')
    ..enableMouseEvents();

  final caps = await t.queryKeyboardCapabilities();
  t.writeln(showCapabilities(caps));

  final s = t.style;
  final colors = (
    aqua: s()..setFg(Color.make('aqua')),
    indianRed: s()..setFg(Color.make('indianRed')),
    darkCyan: s()..setFg(Color.make('darkCyan')),
    magenta: s()..setFg(Color.make('magenta')),
    webGray: s()..setFg(Color.make('webGray')),
    error: s()..setFg(Color.make('red')),
  );

  try {
    while (true) {
      showTick(t, tick, cycle);
      final event = await t.readEvent<Event>();

      switch (event.runtimeType) {
        case NoneEvent:
          continue;
        case ParserErrorEvent:
          t.writeln('ParserErrorEvent: $event');
          continue;
        case KeyEvent:
          final e = event as KeyEvent;
          if (e.code.name == KeyCodeName.escape) break;

          // (e.modifiers.isCapsLock) ? modifiers.write(aqua('L')) : modifiers.write(aquaDark('l'));
          // (e.modifiers.isNumLock) ? modifiers.write(aqua('N')) : modifiers.write(aquaDark('n'));

          final modifiers = getModifiers(colors, e.modifiers);
          final rhsModifiers = getRHSModifiers(colors, e.code.modifiers);
          final lhsModifiers = getLHSModifiers(colors, e.code.modifiers);

          final char = event.code.char.isEmpty ? (colors.webGray('none')) : (colors.magenta(event.code.char));

          final sb = StringBuffer()
            ..write('modifiers: $modifiers, ')
            ..write('char: $char, ')
            ..write('mod ${e.modifiers.value} ')
            ..write('key: ${e.code.name} ');
          if (withKitty) {
            sb
              ..write('\n lhs: $lhsModifiers, ')
              ..write('rhs: $rhsModifiers, ')
              ..write('media: ${e.code.media}, ')
              ..write('base: ${e.code.baseLayoutKey}, ')
              ..write('state: ${e.eventState}, ')
              ..writeln('event: ${e.eventType}');
          }

          t.writeln(sb);

          continue;

        case MouseEvent:
          final e = event as MouseEvent;
          final modifiers = getModifiers(colors, e.modifiers);
          final sb = StringBuffer()
            ..write('modifiers: $modifiers, ')
            ..write('button: ${e.button.button} / ${e.button.action}, ')
            ..write('x: ${e.x}, ')
            ..write('y: ${e.y}, ');
          t.writeln(sb);
          continue;

        default:
          t.writeln('Unknown event: $event - ${event.runtimeType} - ${event is NoneEvent} ');
          continue;
      }
      break;
    }
  } catch (e, st) {
    t
      ..writeln(colors.error('Error: $e'))
      ..writeln('$st');
  } finally {
    tick.cancel();
    t
      ..setKeyboardFlags(KeyboardEnhancementFlagsEvent.empty())
      ..disableMouseEvents();

    //t.popCapabilities();
  }
}

void showTick(TermLib t, Timer timer, Cycle<String> cycle) {
  t
    ..savePosition()
    ..moveTo(0, 0)
    ..eraseLine()
    ..write('Press ESC to exit.   ')
    ..write('${cycle.cycle} ')
    ..write(timer.tick)
    ..restorePosition();
}

String getModifiers(Theme colors, KeyModifiers km) {
  final aq = colors.aqua;
  final ad = colors.darkCyan;

  final modifiers = StringBuffer();
  (km.has(KeyModifiers.shift)) ? modifiers.write(aq('S')) : modifiers.write(ad('s'));
  (km.has(KeyModifiers.ctrl)) ? modifiers.write(aq('C')) : modifiers.write(ad('c'));
  (km.has(KeyModifiers.alt)) ? modifiers.write(aq('A')) : modifiers.write(ad('a'));
  (km.has(KeyModifiers.superKey)) ? modifiers.write(aq('K')) : modifiers.write(ad('k'));
  (km.has(KeyModifiers.hyper)) ? modifiers.write(aq('H')) : modifiers.write(ad('h'));
  (km.has(KeyModifiers.meta)) ? modifiers.write(aq('M')) : modifiers.write(ad('m'));

  return modifiers.toString();
}

String getLHSModifiers(Theme colors, ModifierKeyCode km) {
  final aq = colors.aqua;
  final ad = colors.darkCyan;

  final modifiers = StringBuffer();
  (km == ModifierKeyCode.leftShift) ? modifiers.write(aq('S')) : modifiers.write(ad('s'));
  (km == ModifierKeyCode.leftControl) ? modifiers.write(aq('C')) : modifiers.write(ad('c'));
  (km == ModifierKeyCode.leftAlt) ? modifiers.write(aq('A')) : modifiers.write(ad('a'));
  (km == ModifierKeyCode.leftSuper) ? modifiers.write(aq('K')) : modifiers.write(ad('k'));
  (km == ModifierKeyCode.leftHyper) ? modifiers.write(aq('H')) : modifiers.write(ad('h'));
  (km == ModifierKeyCode.leftMeta) ? modifiers.write(aq('M')) : modifiers.write(ad('m'));

  return modifiers.toString();
}

String getRHSModifiers(Theme colors, ModifierKeyCode km) {
  final aq = colors.aqua;
  final ad = colors.darkCyan;

  final modifiers = StringBuffer();
  (km == ModifierKeyCode.rightShift) ? modifiers.write(aq('S')) : modifiers.write(ad('s'));
  (km == ModifierKeyCode.rightControl) ? modifiers.write(aq('C')) : modifiers.write(ad('c'));
  (km == ModifierKeyCode.rightAlt) ? modifiers.write(aq('A')) : modifiers.write(ad('a'));
  (km == ModifierKeyCode.rightSuper) ? modifiers.write(aq('K')) : modifiers.write(ad('k'));
  (km == ModifierKeyCode.rightHyper) ? modifiers.write(aq('H')) : modifiers.write(ad('h'));
  (km == ModifierKeyCode.rightMeta) ? modifiers.write(aq('M')) : modifiers.write(ad('m'));

  return modifiers.toString();
}

String showCapabilities(KeyboardEnhancementFlagsEvent? flags) {
  if (flags == null) return 'unable to retrieve keyboard capabilities';

  final sb = StringBuffer()
    ..writeln('Keyboard capabilities:')
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes).toString().padLeft(5)}: Disambiguate Escape Codes',
    )
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlagsEvent.reportEventTypes).toString().padLeft(5)}: Report Event Types',
    )
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys).toString().padLeft(5)}: Report Alternate Keys',
    )
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes).toString().padLeft(5)}: Report All Keys As Escape Codes',
    );

  return sb.toString();
}
