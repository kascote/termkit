import 'dart:async';

import 'package:termlib/termlib.dart';

import './cycle.dart';

Future<void> main(List<String> arguments) async {
  final t = TermLib();
  final withKitty = arguments.contains('-kitty');

  if (withKitty) {
    const keyFlags = KeyboardEnhancementFlags(
      KeyboardEnhancementFlags.disambiguateEscapeCodes |
          KeyboardEnhancementFlags.reportAlternateKeys |
          KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes |
          KeyboardEnhancementFlags.reportEventTypes,
    );
    t.setCapabilities(keyFlags);
  }

  await t.withRawModeAsync(() => keyViewer(t, withKitty));
  await t.flushThenExit(0);
}

Future<void> keyViewer(TermLib t, bool withKitty) async {
  final cycle = Cycle(['|', '/', '-', r'\']);
  final tick = Timer.periodic(const Duration(milliseconds: 100), (timer) => timer.tick);

  t
    ..eraseClear()
    ..writeLn(' ')
    ..writeLn(' ');

  final caps = await t.requestCapabilities();
  t.writeLn(showCapabilities(caps));

  final p = t.profile;
  final colors = <String, Style>{
    'aqua': p.style()..setFg(p.getColor('aqua')),
    'indianRed': p.style()..setFg(p.getColor('indianRed')),
    'darkCyan': p.style()..setFg(p.getColor('darkCyan')),
    'magenta': p.style()..setFg(p.getColor('magenta')),
    'webGray': p.style()..setFg(p.getColor('webGray')),
    'error': p.style()..setFg(p.getColor('red')),
  };

  try {
    while (true) {
      showTick(t, tick, cycle);
      final event = await t.readEvent();

      switch (event.runtimeType) {
        case NoneEvent:
          continue;
        case ParserErrorEvent:
          t.writeLn('ParserErrorEvent: $event');
          continue;
        case KeyEvent:
          final e = event as KeyEvent;
          if (e.code.name == KeyCodeName.escape) break;

          // (e.modifiers.isCapsLock) ? modifiers.write(aqua..setText('L')) : modifiers.write(aquaDark..setText('l'));
          // (e.modifiers.isNumLock) ? modifiers.write(aqua..setText('N')) : modifiers.write(aquaDark..setText('n'));

          final modifiers = getModifiers(colors, e.modifiers);
          final rhsModifiers = getRHSModifiers(colors, e.code.modifiers);
          final lhsModifiers = getLHSModifiers(colors, e.code.modifiers);

          final char =
              '${event.code.char.isEmpty ? (colors['webGray']!..setText('none')) : (colors['magenta']!..setText(event.code.char))}';

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

          t.writeLn(sb);

          continue;

        default:
          t.writeLn('Unknown event: $event - ${event.runtimeType} - ${event is NoneEvent} ');
          continue;
      }
      break;
    }
  } catch (e, st) {
    t
      ..writeLn(colors['error']!..setText('Error: $e'))
      ..writeLn('$st');
  } finally {
    tick.cancel();
    t.setCapabilities(KeyboardEnhancementFlags.empty());
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

String getModifiers(Map<String, Style> colors, KeyModifiers km) {
  final aqua = colors['aqua']!;
  final aquaDark = colors['darkCyan']!;

  final modifiers = StringBuffer();
  (km.has(KeyModifiers.shift)) ? modifiers.write(aqua..setText('S')) : modifiers.write(aquaDark..setText('s'));
  (km.has(KeyModifiers.ctrl)) ? modifiers.write(aqua..setText('C')) : modifiers.write(aquaDark..setText('c'));
  (km.has(KeyModifiers.alt)) ? modifiers.write(aqua..setText('A')) : modifiers.write(aquaDark..setText('a'));
  (km.has(KeyModifiers.superKey)) ? modifiers.write(aqua..setText('K')) : modifiers.write(aquaDark..setText('k'));
  (km.has(KeyModifiers.hyper)) ? modifiers.write(aqua..setText('H')) : modifiers.write(aquaDark..setText('h'));
  (km.has(KeyModifiers.meta)) ? modifiers.write(aqua..setText('M')) : modifiers.write(aquaDark..setText('m'));

  return modifiers.toString();
}

String getLHSModifiers(Map<String, Style> colors, ModifierKeyCode km) {
  final aqua = colors['aqua']!;
  final aquaDark = colors['darkCyan']!;

  final modifiers = StringBuffer();
  (km == ModifierKeyCode.leftShift) ? modifiers.write(aqua..setText('S')) : modifiers.write(aquaDark..setText('s'));
  (km == ModifierKeyCode.leftControl) ? modifiers.write(aqua..setText('C')) : modifiers.write(aquaDark..setText('c'));
  (km == ModifierKeyCode.leftAlt) ? modifiers.write(aqua..setText('A')) : modifiers.write(aquaDark..setText('a'));
  (km == ModifierKeyCode.leftSuper) ? modifiers.write(aqua..setText('K')) : modifiers.write(aquaDark..setText('k'));
  (km == ModifierKeyCode.leftHyper) ? modifiers.write(aqua..setText('H')) : modifiers.write(aquaDark..setText('h'));
  (km == ModifierKeyCode.leftMeta) ? modifiers.write(aqua..setText('M')) : modifiers.write(aquaDark..setText('m'));

  return modifiers.toString();
}

String getRHSModifiers(Map<String, Style> colors, ModifierKeyCode km) {
  final aqua = colors['aqua']!;
  final aquaDark = colors['darkCyan']!;

  final modifiers = StringBuffer();
  (km == ModifierKeyCode.rightShift) ? modifiers.write(aqua..setText('S')) : modifiers.write(aquaDark..setText('s'));
  (km == ModifierKeyCode.rightControl) ? modifiers.write(aqua..setText('C')) : modifiers.write(aquaDark..setText('c'));
  (km == ModifierKeyCode.rightAlt) ? modifiers.write(aqua..setText('A')) : modifiers.write(aquaDark..setText('a'));
  (km == ModifierKeyCode.rightSuper) ? modifiers.write(aqua..setText('K')) : modifiers.write(aquaDark..setText('k'));
  (km == ModifierKeyCode.rightHyper) ? modifiers.write(aqua..setText('H')) : modifiers.write(aquaDark..setText('h'));
  (km == ModifierKeyCode.rightMeta) ? modifiers.write(aqua..setText('M')) : modifiers.write(aquaDark..setText('m'));

  return modifiers.toString();
}

String showCapabilities(KeyboardEnhancementFlags? flags) {
  if (flags == null) return 'unable to retrieve keyboard capabilities';

  final sb = StringBuffer()
    ..writeln('Keyboard capabilities:')
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlags.disambiguateEscapeCodes).toString().padLeft(5)}: Disambiguate Escape Codes',
    )
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlags.reportEventTypes).toString().padLeft(5)}: Report Event Types',
    )
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlags.reportAlternateKeys).toString().padLeft(5)}: Report Alternate Keys',
    )
    ..writeln(
      '  ${flags.has(KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes).toString().padLeft(5)}: Report All Keys As Escape Codes',
    );

  return sb.toString();
}
