import 'package:termlib/termlib.dart';

typedef Theme = ({
  Style green,
  Style magenta,
  Style yellow,
  Style error,
});

Future<void> main() async {
  final t = TermLib()
    ..enableRawMode()
    ..writeln('terminal info:\n');

  final p = t.profile;
  final theme = (
    magenta: t.profile.style()..setFg(p.getColor('magenta')),
    green: t.profile.style()..setFg(p.getColor('green')),
    yellow: t.profile.style()..setFg(p.getColor('yellow')),
    error: t.profile.style()..setFg(p.getColor('red')),
  );

  final version = await t.queryTerminalVersion();
  final keyCap = await t.requestKeyboardCapabilities();
  final fgColor = await t.foregroundColor();
  final bgColor = await t.backgroundColor();
  final syncStatus = await t.querySyncUpdate();

  t
    ..writeln('Terminal version: ${theme.yellow(version)}')
    ..writeln('dimensions ${theme.yellow('${t.windowWidth}x${t.windowHeight}')}')
    ..writeln('Sync update status: ${renderValue(syncStatus.name, theme)}')
    ..writeln('Foreground color: ${theme.yellow(fgColor.toString())}')
    ..writeln('Background color: ${theme.yellow(bgColor.toString())}');
  showKeyboardCapabilities(t, theme, keyCap);
  t.disableRawMode();

  await t.flushThenExit(0);
}

String renderValue(String value, Theme theme) {
  return switch (value) {
    'enabled' || 'true' => theme.green(value),
    'disabled' || 'unknown' || 'false' => theme.magenta(value),
    _ => theme.error(value),
  };
}

void showKeyboardCapabilities(TermLib t, Theme theme, KeyboardEnhancementFlags? flags) {
  if (flags == null) {
    return t.writeln(theme.error('unable to retrieve keyboard capabilities'));
  }

  String showFlag(bool value, String name) => '  ${renderValue(value.toString(), theme)} $name';

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
