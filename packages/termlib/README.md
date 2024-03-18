# TermLib

Dart library that provides a set of utilities for terminal applications.
Provides information about the running terminal as well as a set of methods
for styling the text output or interacting with the terminal.

## Features

- Keyboard input handling (including Kitty protocol)
- Mouse events
- Focus tracking
- Line wrapping
- Terminal scrolling
- Synchronous update mode
- Terminal hyperlinking
- Terminal notifications
- RGB/TrueColor support
- Convert colors to the best matching if needed
- Bracketed Paste
- a lot more...

## Getting Started

Add `termlib` to your `pubspec.yaml` file:

```yaml
dependencies:
  termlib: ^0.1.0
```

Then, run `flutter pub get` to fetch the package.

## Usage

Here's a simple example of using `termlib`:

```dart
import 'dart:io';

import 'package:termlib/termlib.dart';

Future<void> main() async {
  final t = TermLib();
  final color = await t.isBackgroundDark() ? Color('yellow') : Color('blue');

  t
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My Terminal Application')
    ..writeAt(5, 5, t.style('Hello, World!')..fg(color));

  sleep(const Duration(seconds: 2));

  t
    ..disableAlternateScreen()
    ..cursorShow();
  await t.flushThenExit(0);
}
```

## Examples

You can find more examples of how to use `termlib` in the [example directory](packages/termlib/example).

## Acknowledges

This library __borrows a lot__ of inspiration and ideas from this other great libraries:

- [dart_console](https://github.com/timsneath/dart_console)
- [crossterm](https://github.com/crossterm-rs/crossterm)
- [termenv](https://github.com/muesli/termenv)
- [termwiz](https://github.com/wez/wezterm/tree/main/termwiz)
- [vaxis](https://sr.ht/~rockorager/vaxis/)
- [mason](https://github.com/felangel/mason)

## License

`termlib` is licensed under the [MIT license](LICENSE).
