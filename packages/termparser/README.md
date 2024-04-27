# TermParser

ANSI Terminal escape sequence parser.

This parser is loose implementation of Paul Flo Williams' [VT500-series parser](https://vt100.net/emu/dec_ansi_parser).
It take a lot of ideas from the [annes](https://github.com/qwandor/anes-rs) project, and
extends it in some areas.

This library is part of the [termKit](https://github.com/kascote/termkit)
project.

## Features

Still is a works in progress, but the following features are implemented:

- Normal key mode
- Enhanced key mode (Kitty protocol)
- Mouse tracking
- Cursor position report
- Focus events
- Color query requests
- Device attributes
- Bracketing paste
- and more...

## Usage

This is a simple example how to get started with the package.

```dart
  final parser = Parser();
  // ESC [ 20 ; 10 R
  parser.advance([0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52]);
  assert(parser.moveNext(), 'unable to get next sequence');
  assert(parser.current == const CursorPositionEvent(20, 10), 'retrieve event');
  assert(parser.moveNext() == false, 'no more events');
```

## Acknowledgements

This package is _**strongly influenced**_ by the following projects:

- [annes](https://github.com/qwandor/anes-rs)
- [vaxis](https://git.sr.ht/~rockorager/vaxis)

## License

`termparser` is licensed under the [MIT license](LICENSE).
