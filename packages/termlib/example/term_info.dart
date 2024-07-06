import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

typedef Theme = ({
  Style green,
  Style magenta,
  Style yellow,
  Style error,
});

Future<void> main() async {
  final t = TermLib();

  final s = t.style;
  final theme = (
    magenta: s()..fg(Color('201')),
    green: s()..fg(Color('40')),
    yellow: s()..fg(Color('190')),
    error: s()..fg(Color('160')),
  );

  final version = await t.queryTerminalVersion();
  final keyCap = await t.queryKeyboardCapabilities();
  final fgColor = await t.foregroundColor;
  final bgColor = await t.backgroundColor;
  final syncStatus = await t.querySyncUpdate();
  final keyEnhanced = await t.queryKeyboardEnhancementSupport();
  final deviceAttr = await t.queryPrimaryDeviceAttributes();
  final termPixels = await t.queryWindowSizeInPixels();

  t
    ..writeln('Terminal version: ${theme.green(version)}')
    ..writeln('dimension chars: ${theme.green('${t.terminalColumns}x${t.terminalLines}')}')
    ..writeln('dimension pixels: ${theme.green('${termPixels?.width ?? ''}x${termPixels?.height ?? ''}')}')
    ..writeln('Color profile: ${theme.green(t.profile.name)}')
    ..writeln('Sync update status: ${renderValue(syncStatus?.name ?? 'unsupported', theme)}')
    ..writeln('Foreground color: ${theme.yellow(fgColor.toString())}')
    ..writeln('Background color: ${theme.yellow(bgColor.toString())}')
    ..writeln('Primary device Attrs:');
  showDeviceAttr(t, deviceAttr, theme);
  t.writeln('Keyboard Enhancement support: ${renderValue(keyEnhanced.toString(), theme)}');
  if (keyEnhanced) showKeyboardCapabilities(t, theme, keyCap);

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

  String showFlag(String value, String name) => '  ${renderValue(value, theme)} $name';

  t
    ..writeln('Keyboard capabilities:')
    ..writeln(
      '  ${showFlag(
        flags.has(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes).toString(),
        "Disambiguate Escape Codes",
      )}',
    )
    ..writeln(
      '  ${showFlag(
        flags.has(KeyboardEnhancementFlagsEvent.reportEventTypes).toString(),
        "Report Event Types",
      )}',
    )
    ..writeln(
      '  ${showFlag(
        flags.has(KeyboardEnhancementFlagsEvent.reportAlternateKeys).toString(),
        "Report Alternate Keys",
      )}',
    )
    ..writeln(
      '  ${showFlag(
        flags.has(KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes).toString(),
        "Report All Keys As Escape Codes",
      )}',
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

  for (final p in deviceAttr.params) {
    t.writeln('    ${theme.green(p.name)}');
  }
}
