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

void main() {
  final t = TermLib();
  final p = t.profile;

  t
    ..enableAlternateScreen()
    ..eraseClear()
    ..cursorHide()
    ..setTerminalTitle('My Terminal Application')
    ..writeAt(
      10,
      10,
      p.style('Hello, World!')..setFg(t.profile.getColor('yellow')),
    );

  sleep(const Duration(seconds: 2));

  t
    ..disableAlternateScreen()
    ..cursorShow()
    ..flushThenExit(0);
}
```

## Examples

You can find more examples of how to use `termlib` in the [example directory](packages/termlib/example).

## License

`termlib` is licensed under the [MIT license](LICENSE).
