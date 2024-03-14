import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

typedef Theme = ({
  Style green,
  Style magenta,
  Style yellow,
  Style error,
});

Future<void> main() async {
  final t = TermLib()..enableRawMode();

  final p = t.profile;
  final theme = (
    magenta: p.style()..setFg(p.getColor('201')),
    green: p.style()..setFg(p.getColor('40')),
    yellow: p.style()..setFg(p.getColor('190')),
    error: p.style()..setFg(p.getColor('160')),
  );

  final version = await t.queryTerminalVersion();
  final keyCap = await t.queryKeyboardCapabilities();
  final fgColor = await t.foregroundColor;
  final bgColor = await t.backgroundColor;
  final syncStatus = await t.querySyncUpdate();
  final keyEnhanced = await t.queryKeyboardEnhancementSupport();
  final deviceAttr = await t.queryPrimaryDeviceAttributes();

  t
    ..writeln('Terminal version: ${theme.green(version)}')
    ..writeln('dimensions ${theme.green('${t.windowWidth}x${t.windowHeight}')}')
    ..writeln('Color profile: ${theme.green(p.profile.name)}')
    ..writeln('Sync update status: ${renderValue(syncStatus?.name ?? 'unsupported', theme)}')
    ..writeln('Foreground color: ${theme.yellow(fgColor.toString())}')
    ..writeln('Background color: ${theme.yellow(bgColor.toString())}')
    ..writeln('Primary device Attrs:');
  showDeviceAttr(t, deviceAttr, theme);
  t.writeln('Keyboard Enhancement support: ${renderValue(keyEnhanced.toString(), theme)}');
  if (keyEnhanced) showKeyboardCapabilities(t, theme, keyCap);
  t.disableRawMode();

  await t.flushThenExit(0);
}

String renderValue(String value, Theme theme) {
  return switch (value) {
    'enabled' || 'true' => theme.green(value),
    'disabled' || 'unknown' || 'false' || 'unsupported' => theme.magenta(value),
    _ => theme.error(value),
  };
}

void showKeyboardCapabilities(TermLib t, Theme theme, KeyboardEnhancementFlagsEvent? flags) {
  if (flags == null) {
    return t.writeln(theme.error('unable to retrieve keyboard capabilities'));
  }

  String showFlag(bool value, String name) => '  ${renderValue(value.toString(), theme)} $name';

  t
    ..writeln('Keyboard capabilities:')
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes), "Disambiguate Escape Codes")}',
    )
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlagsEvent.reportEventTypes), "Report Event Types")}',
    )
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys), "Report Alternate Keys")}',
    )
    ..writeln(
      '  ${showFlag(flags.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes), "Report All Keys As Escape Codes")}',
    );
}

void showDeviceAttr(TermLib t, PrimaryDeviceAttributesEvent? deviceAttr, Theme theme) {
  if (deviceAttr == null) {
    return t.writeln('  ${theme.error('unable to retrieve device attributes')}');
  }

  t
    ..writeln('  Type: ${theme.green(deviceAttr.type.name)}')
    ..writeln('  Params:');
  if (deviceAttr.params.isEmpty) {
    t.writeln('    ${theme.yellow('no params')}');
    return;
  }
  deviceAttr.params.forEach((p) => t.writeln('    ${theme.green(p.name)}'));
}
