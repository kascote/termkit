# TermLib

Dart library for terminal applications. Part of [termKit](https://github.com/kascote/termkit).

## Features

- Text styling (colors, bold, italic, underlines, etc.)
- RGB/TrueColor with automatic down sampling
- Cursor control, screen clearing, alternate screen
- Keyboard input (including Kitty protocol)
- Mouse events, focus tracking
- Terminal hyperlinking, notifications
- Bracketed paste
- Synchronous updates

## Installation

```yaml
dependencies:
  termlib: ^0.1.0
```

## Quick Start

### Output and Styling

```dart
import 'package:termlib/termlib.dart';

Future<void> main() async {
  final term = TermLib();

  // Simple output
  term.writeln('Hello, terminal!');

  // Styled text
  term.writeln(term.style('Bold text')..bold());
  term.writeln(term.style('Red on blue')..fg(Color.red)..bg(Color.blue));

  // RGB colors (auto-downsamples if terminal doesn't support)
  term.writeln(term.style('Custom color')..fg(Color.fromString('#ff6600')));

  await term.dispose();
  await term.flushThenExit(0);
}
```

### Terminal Control

```dart
import 'dart:io';
import 'package:termlib/termlib.dart';

Future<void> main() async {
  final term = TermLib();

  term
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My App')
    ..writeAt(5, 5, term.style('Hello!')..fg(Color.cyan));

  sleep(const Duration(seconds: 2));

  term
    ..disableAlternateScreen()
    ..cursorShow();

  await term.dispose();
  await term.flushThenExit(0);
}
```

## TermRunner

Recommended for apps needing raw mode, alternate screen, or signal handling. Handles setup, cleanup, and error recovery automatically:

```dart
import 'package:termlib/termlib.dart';

Future<void> main() async {
  await TermRunner(
    alternateScreen: true,
    rawMode: true,
    hideCursor: true,
    mouseEvents: true,
    title: 'My App',
  ).run((term) async {
    term.writeln('Press q to quit');

    while (true) {
      final event = await term.read<KeyEvent>();
      if (event is KeyEvent && event.char == 'q') break;
      term.writeln('Key: ${event}');
    }

    return 0; // exit code
  });
}
```

**Features:**

- Auto cleanup on normal exit, errors, and signals (SIGINT/SIGTERM)
- `onCleanup` callback for resource cleanup
- `onError` callback for custom error handling

## Input Handling

TermLib detects interactive vs piped input automatically.

### Interactive Mode (`hasTerminal == true`)

Events are queued in background. Use `poll()` (non-blocking) or `read()` (blocking):

```dart
...
// Non-blocking poll (for render loops)
final event = term.poll<KeyEvent>();
if (event is KeyEvent) {
  // handle key
}

// Blocking read (for CLI apps)
final event = await term.read<KeyEvent>();
```

### Piped Mode (`hasTerminal == false`)

Use `stdinStream` with transformers:

```dart
import 'dart:convert';

...
if (!term.hasTerminal) {
  await for (final line in term.stdinStream
      .transform(utf8.decoder)
      .transform(LineSplitter())) {
    term.writeln('Line: $line');
  }
}
```

### Raw Mode and Ctrl+C

When raw mode is enabled, Ctrl+C does NOT generate SIGINT - it arrives as a `KeyEvent` and must be handled manually.

## Examples

See the [example directory](example) for more:

- `colors.dart` - Color palettes (ANSI, 256, TrueColor)
- `color_table.dart` - Downsampling demo from 256 to 16 colors
- `key_viewer.dart` - Interactive key event viewer
- `matrix.dart` - Matrix rain effect
- `piped_input.dart` - Processing piped input
- `styles.dart` - Text styling demo
- `snake.dart` - Simple game example
- `term_info.dart` - Terminal capabilities info

## Acknowledgements

Inspired by [dart_console](https://github.com/timsneath/dart_console), [crossterm](https://github.com/crossterm-rs/crossterm), [termenv](https://github.com/muesli/termenv), [termwiz](https://github.com/wez/wezterm/tree/main/termwiz), [vaxis](https://sr.ht/~rockorager/vaxis/), [mason](https://github.com/felangel/mason).

## License

MIT
