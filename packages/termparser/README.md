# TermParser

ANSI escape sequence parser.

This parser is loose implementation of Paul Flo Williams' [VT500-series parser](https://vt100.net/emu/dec_ansi_parser).

## Features

Still is a works in progress, but the following features are implemented:

- Normal key mode
- Enhanced key mode (Kitty protocol)
- Mouse tracking
- Cursor position report
- Focus events
- Color query requests
- Device attributes

## Usage

This is a simple example how to get started with the package.

```dart
  final parser = Parser();
  // ESC [ 20 ; 10 R
  parser.advance([0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52]);
  assert(parser.moveNext(), 'move next');
  assert(parser.current == const CursorPositionEvent(20, 10), 'retrieve event');
  assert(parser.moveNext() == false, 'no more events');
```

## Acknowledgements

This package takes a _**lot**_ of inspiration and ideas from this two great packages:

- [vaxis](https://git.sr.ht/~rockorager/vaxis)
- [annes](https://github.com/qwandor/anes-rs)
