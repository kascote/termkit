import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = TermLib()
    ..rawMode = true
    ..writeln('terminal info:\n');

  final version = await t.requestTerminalVersion();
  final keyCap = await t.requestCapabilities();
  final fgColor = await t.foregroundColor();
  final bgColor = await t.backgroundColor();

  t
    ..writeln('Terminal version: $version')
    ..writeln('dimensions ${t.windowWidth}x${t.windowHeight}');
  showCapabilities(t, keyCap);
  t
    ..writeln('Foreground color: $fgColor')
    ..writeln('Background color: $bgColor')
    ..rawMode = false;

  await t.flushThenExit(0);
}

void showCapabilities(TermLib t, KeyboardEnhancementFlags? flags) {
  final p = t.profile;
  final magenta = t.profile.style()..setFg(p.getColor('magenta'));
  final green = t.profile.style()..setFg(p.getColor('green'));

  if (flags == null) {
    return t.writeln(p.style('unable to retrieve keyboard capabilities')..setFg(p.getColor('red')));
  }

  String showFlag(bool value, String name) {
    final color = value ? green : magenta;
    return '  ${color..setText(value.toString().padLeft(5))} $name';
  }

  t
    ..writeln('Keyboard capabilities:')
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlags.disambiguateEscapeCodes), "Disambiguate Escape Codes")}',
    )
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlags.reportEventTypes), "Report Event Types")}',
    )
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlags.reportAlternateKeys), "Report Alternate Keys")}',
    )
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes), "Report All Keys As Escape Codes")}',
    );
}
