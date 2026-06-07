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
// Runs under `TermRunner` with the Kitty keyboard enhancement enabled, so the
// Alt-prefixed word shortcuts (Alt+B/F/D, Alt+Backspace) are disambiguated and
// reliably reach `readLine` instead of arriving as a bare ESC + char. The
// runner also probes at startup and restores the keyboard state on exit.
//
import 'package:characters/characters.dart';
import 'package:termlib/termlib.dart';

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? 'plain' : args.first;

  // `run` builds the term, probes once (seeding TermInfo for bracketed-paste
  // decisions), enables Kitty keyboard enhancement for the session, then
  // restores and exits via `flushThenExit` when the callback returns.
  await TermRunner(keyboardEnhancement: true).run((t) async {
    final (options, banner) = _configFor(t, mode);

    t
      ..writeln('readline example — mode: $mode  (Enter submits, Esc cancels)')
      ..writeln(banner)
      ..writeln(
        'Shortcuts: Ctrl+W / Alt+Backspace kill word · Alt+B/F word motion · '
        'Alt+D kill word forward · Ctrl+Y yank · Ctrl+T transpose · Ctrl+L clear.',
      )
      ..writeln('');

    final input = await t.readLine(options);

    if (input == null) {
      t.writeln('${t.newLine}Cancelled${t.newLine}');
    } else {
      t.writeln('${t.newLine}You typed (${input.characters.length} graphemes): [$input]${t.newLine}');
    }
    return 0;
  });
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
      // Mixed graphemes to exercise cursor motion over multi-codepoint clusters:
      //   👩‍💻 / 👨‍👩‍👧‍👦 / 🏳️‍🌈  ZWJ sequences (joined codepoints)
      //   👋🏽                      skin-tone modifier (longer rep)
      //   🇺🇸                      regional-indicator flag (two codepoints)
      // Some sit apart (move word-by-word over text) and the flags 🇺🇸🏳️‍🌈 sit
      // adjacent, so left/right must step a whole cluster at a time.
      return (
        const ReadlineOptions(
          visualLength: 24,
          initBuffer: 'the coder 👩‍💻 waves 👋🏽 bye as the family 👨‍👩‍👧‍👦 sails 🇺🇸🏳️‍🌈 home — type past the edge to scroll',
        ),
        'visualLength: 24, wrap: false — one row, horizontal scroll over wide graphemes.',
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
