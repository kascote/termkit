import 'package:termlib/termlib.dart';

// Theme record for consistent styling
typedef Theme = ({
  Style green,
  Style magenta,
  Style yellow,
  Style white,
  Style text,
});

Future<int> main() async {
  return TermRunner().run(display);
}

Future<int> display(TermLib t) async {
  final theme = _buildTheme(t);

  final info = await t.probe();

  _section(t, theme, 'Terminal Info');
  _showResult(t, theme, 'Version', info.terminalVersion);
  t.writeln('  ${theme.text('Dimensions (chars)')}: ${theme.green('${t.terminalColumns}x${t.terminalLines}')}');
  _showResult(t, theme, 'Dimensions (pixels)', info.windowSizePixels, (v) => '${v.width}x${v.height}');
  t.writeln('  ${theme.text('Color profile')}: ${theme.green(t.profile.name)}');

  _section(t, theme, 'Colors');
  _showResult(t, theme, 'Foreground', info.foregroundColor, (v) => v.value.toRadixString(16));
  _showResult(t, theme, 'Background', info.backgroundColor, (v) => v.value.toRadixString(16));

  _section(t, theme, 'Protocol Support');
  _showResult(t, theme, 'Sync update', info.syncUpdate, (v) => v.name);
  _showResult(t, theme, 'Unicode Core', info.unicodeCore, (v) => v.name);

  _section(t, theme, 'Device Attributes');
  _showDeviceAttrs(t, theme, info.deviceAttrs);

  _section(t, theme, 'Keyboard');
  _showKeyboardFlags(t, theme, info.keyboardCapabilities);

  return 0;
}

Theme _buildTheme(TermLib t) {
  final s = t.style;
  return (
    green: s()..fg(Color.indexed(40)),
    magenta: s()..fg(Color.indexed(201)),
    yellow: s()..fg(Color.indexed(190)),
    white: s()..fg(Color.indexed(15)),
    text: s()..fg(Color.indexed(7)),
  );
}

// --- Display helpers ---

void _section(TermLib t, Theme theme, String title) {
  t
    ..writeln('')
    ..writeln(theme.white(title));
}

void _showResult<T>(
  TermLib t,
  Theme theme,
  String label,
  QueryResult<T> result, [
  String Function(T)? format,
]) {
  final styled = switch (result) {
    Supported(:final value) => theme.green(format != null ? format(value) : value.toString()),
    Unavailable(:final reason) => theme.magenta(reason.name),
    Pending() => theme.yellow('pending'),
  };
  t.writeln('  ${theme.text(label)}: $styled');
}

// --- Device attributes ---

void _showDeviceAttrs(TermLib t, Theme theme, QueryResult<DeviceAttributes> result) {
  switch (result) {
    case Supported(:final value):
      t.writeln('  ${theme.text('Type')}: ${theme.green(value.type.name)}');
      if (value.params.isEmpty) {
        t.writeln('  ${theme.text('Params')}: ${theme.yellow('none')}');
      } else {
        t.writeln('  ${theme.text('Params')}:');
        for (final p in value.params) {
          t.writeln('    ${theme.green(p.name)}');
        }
      }
    case Unavailable(:final reason):
      t.writeln('  ${theme.magenta(reason.name)}');
    case Pending():
      t.writeln('  ${theme.yellow('pending')}');
  }
}

// --- Keyboard flags ---

void _showKeyboardFlags(TermLib t, Theme theme, QueryResult<KeyboardFlags> result) {
  switch (result) {
    case Supported(:final value):
      t.writeln('  ${theme.text('Enhanced keyboard')}: ${theme.green('supported')}');
      _flag(t, theme, 'Disambiguate escape codes', value.disambiguateEscapeCodes);
      _flag(t, theme, 'Report event types', value.reportEventTypes);
      _flag(t, theme, 'Report alternate keys', value.reportAlternateKeys);
      _flag(t, theme, 'Report all keys as escape codes', value.reportAllKeysAsEscapeCodes);
      _flag(t, theme, 'Report associated text', value.reportAssociatedText);
    case Unavailable(:final reason):
      t.writeln('  ${theme.text('Enhanced keyboard')}: ${theme.magenta(reason.name)}');
    case Pending():
      t.writeln('  ${theme.yellow('pending')}');
  }
}

void _flag(TermLib t, Theme theme, String name, bool value) {
  final status = value ? theme.green('yes') : theme.magenta('no');
  t.writeln('    ${theme.text(name)}: $status');
}
