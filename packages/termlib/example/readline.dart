// Readline example.
//
// Demonstrates the different `readLine` modes. Run with one of:
//
//   dart run example/readline.dart            # plain line input
//   dart run example/readline.dart prompt     # styled prompt
//   dart run example/readline.dart max        # capped at 10 graphemes
//   dart run example/readline.dart scroll     # narrow area, horizontal scroll
//   dart run example/readline.dart wrap       # narrow area, soft-wrap to rows
//   dart run example/readline.dart all        # prompt + maxLength + wrap
//
import 'package:characters/characters.dart';
import 'package:termlib/termlib.dart';

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? 'plain' : args.first;
  final t = Term.open() as InteractiveTerm;

  // Probe once at startup; readLine relies on the cached TermInfo to decide
  // whether to use bracketed paste (no per-call re-query).
  await t.probe();

  final (options, banner) = _configFor(t, mode);

  t
    ..writeln('readline example — mode: $mode  (Enter submits, Esc cancels)')
    ..writeln(banner)
    ..writeln('');

  final input = await t.readLine(options);

  if (input == null) {
    t.writeln('${t.newLine}Cancelled${t.newLine}');
  } else {
    t.writeln('${t.newLine}You typed (${input.characters.length} graphemes): [$input]${t.newLine}');
  }

  await t.dispose();
  return t.flushThenExit(0);
}

(ReadlineOptions, String) _configFor(InteractiveTerm t, String mode) {
  switch (mode) {
    case 'prompt':
      final promptStyle = t.style(fg: Color.fromString('cyan'));
      return (
        ReadlineOptions(prompt: 'name› ', promptStyle: promptStyle),
        'A styled, display-only prompt owned by the widget.',
      );

    case 'max':
      return (
        const ReadlineOptions(maxLength: 10),
        'maxLength: 10 — extra input is silently blocked; backspace still works.',
      );

    case 'scroll':
      return (
        const ReadlineOptions(visualLength: 24, initBuffer: 'edit me — type past the right edge to scroll'),
        'visualLength: 24, wrap: false — one row, horizontal scroll.',
      );

    case 'wrap':
      return (
        const ReadlineOptions(visualLength: 24, wrap: true),
        'visualLength: 24, wrap: true — text soft-wraps onto more rows.',
      );

    case 'all':
      final promptStyle = t.style(fg: Color.fromString('green'));
      return (
        ReadlineOptions(prompt: '> ', promptStyle: promptStyle, maxLength: 120, wrap: true),
        'prompt + maxLength: 120 + wrap. Resize the window to see it reflow.',
      );

    case 'plain':
    default:
      return (const ReadlineOptions(), 'Plain full-width line input.');
  }
}
