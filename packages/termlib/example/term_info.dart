import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

typedef Theme = ({
  Style green,
  Style magenta,
  Style yellow,
  Style error,
  Style white,
  Style text,
});

Future<int> main() async {
  final exitCode = await TermRunner().run(display);
  return exitCode;
}

Future<int> display(TermLib t) async {
  final s = t.style;
  final theme = (
    magenta: s()..fg(Color.indexed(201)),
    green: s()..fg(Color.indexed(40)),
    yellow: s()..fg(Color.indexed(190)),
    error: s()..fg(Color.indexed(160)),
    white: s()..fg(Color.indexed(15)),
    text: s()..fg(Color.indexed(7)),
  );

  final version = await t.queryTerminalVersion();
  final keyCap = await t.queryKeyboardCapabilities();
  final fgColor = await t.foregroundColor;
  final bgColor = await t.backgroundColor;
  final syncStatus = await t.querySyncUpdate();
  final keyEnhanced = await t.queryKeyboardEnhancementSupport();
  final deviceAttr = await t.queryPrimaryDeviceAttributes();
  final termPixels = await t.queryWindowSizeInPixels();
  final unicodeCore = await t.queryUnicodeCore();

  t
    ..writeln('${theme.white('Terminal version: ')}${theme.green(version)}')
    ..writeln('${theme.white('dimension chars: ')}${theme.green('${t.terminalColumns}x${t.terminalLines}')}')
    ..writeln(
      '${theme.white('dimension pixels: ')}${theme.green('${termPixels?.width ?? ''}x${termPixels?.height ?? ''}')}',
    )
    ..writeln('${theme.white('Color profile: ')}${theme.green(t.profile.name)}')
    ..writeln('${theme.white('Sync update status: ')}${renderValue(syncStatus?.status.name ?? 'unsupported', theme)}')
    ..writeln('${theme.white('Foreground color: ')}${theme.yellow(fgColor.toString())}')
    ..writeln('${theme.white('Background color: ')}${theme.yellow(bgColor.toString())}')
    ..writeln('${theme.white('Unicode Core: ')}${renderValue(unicodeCore?.status.name ?? 'unsupported', theme)}')
    ..writeln(theme.white('Primary device Attrs:'));
  showDeviceAttr(t, deviceAttr, theme);
  t.writeln('${theme.white('Keyboard Enhancement support: ')}${renderValue(keyEnhanced.toString(), theme)}');
  if (keyEnhanced) showKeyboardCapabilities(t, theme, keyCap);

  return 0;
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

  String showFlag(String value, String name) => '  ${renderValue(value, theme)} ${theme.text(name)}';

  t
    ..writeln(theme.white('Keyboard capabilities:'))
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
    ..writeln('  ${theme.white('Type: ')}${theme.green(deviceAttr.type.name)}')
    ..writeln('  ${theme.white('Params:')}');
  if (deviceAttr.params.isEmpty) {
    t.writeln('    ${theme.yellow('no params')}');
    return;
  }

  for (final p in deviceAttr.params) {
    t.writeln('    ${theme.green(p.name)}');
  }
}
