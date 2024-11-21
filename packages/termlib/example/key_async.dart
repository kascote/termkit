import 'dart:async';
import 'dart:io';

import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import './shared.dart';

typedef Theme = ({
  Style aqua,
  Style white,
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
  final resetCR = '${Style('')..resetStyle()}\n';

  t
    ..eraseClear()
    ..writeln(' ')
    ..writeln(' ')
    ..enableMouseEvents();

  final caps = await t.queryKeyboardCapabilities();
  t.writeln(showCapabilities(caps));

  final s = t.style;
  final colors = (
    aqua: s()
      ..fg(Color.fromString('aqua'))
      ..bg(Color.reset),
    white: s()
      ..fg(Color.fromString('white'))
      ..bg(Color.reset),
    darkCyan: s()
      ..fg(Color.fromString('darkCyan'))
      ..bg(Color.reset),
    magenta: s()
      ..fg(Color.fromString('magenta'))
      ..bg(Color.reset),
    webGray: s()
      ..fg(Color.fromString('webGray'))
      ..bg(Color.reset),
    error: s()
      ..fg(Color.fromString('red'))
      ..bg(Color.reset),
  );

  try {
    while (true) {
      showTick(t, tick, cycle, colors);
      final event = await t.readEvent<Event>();
      final wg = colors.webGray;
      final dc = colors.darkCyan;

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
            ..write('${wg('modifiers: ')}$modifiers ')
            ..write('${wg('char: ')}$char ')
            ..write('${wg('mod: ')}${colors.magenta(e.modifiers.value)} ')
            ..write('${wg('key: ')}${colors.magenta(e.code.name)} ');
          if (withKitty) {
            sb
              ..write(resetCR)
              ..write('${wg('  lhs: ')}$lhsModifiers, ')
              ..write('${wg('rhs: ')}$rhsModifiers, ')
              ..write('${wg('media: ')}${dc(e.code.media)}, ')
              ..write('${wg('base: ')}${dc(e.code.baseLayoutKey)}, ')
              ..write('${wg('state: ')}${dc(e.eventState)}, ')
              ..writeln('event: ${dc(e.eventType)}');
          }

          t.writeln(sb);

          continue;

        case MouseEvent:
          final e = event as MouseEvent;
          final modifiers = getModifiers(colors, e.modifiers);
          final sb = StringBuffer()
            ..write('${wg('modifiers: ')}$modifiers, ')
            ..write('${wg('button: ')}${dc(e.button.button)} ${wg('/')} ${dc(e.button.action)}, ')
            ..write('${wg('x: ')}${dc(e.x)}, ')
            ..write('${wg('y: ')}${dc(e.y)}, ');
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

void showTick(TermLib t, Timer timer, Cycle<String> cycle, Theme colors) {
  t
    ..savePosition()
    ..moveTo(0, 0)
    ..eraseLine()
    ..write(colors.white('Press ESC to exit.   '))
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

  modifiers.write(ad(' (${km.value}) '));

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

  modifiers.write(ad(' (${km.index}) '));

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

  modifiers.write(ad(' (${km.index}) '));
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
