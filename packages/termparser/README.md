# TermParser

ANSI Terminal escape sequence parser.

This parser is loose implementation of Paul Flo Williams' [VT500-series parser](https://vt100.net/emu/dec_ansi_parser).
It take a lot of ideas from the [annes](https://github.com/qwandor/anes-rs) project, and
extends it in some areas.

This library is part of the [termKit](https://github.com/kascote/termkit)
project.

## Features

- Normal key mode + Enhanced key mode (Kitty protocol)
- Mouse tracking (SGR format)
- Cursor position reports (CPR)
- Focus events
- Color queries (OSC 10/11)
- Device attributes (DA1)
- Bracketed paste
- Clipboard operations (OSC 52)
- Terminal size queries
- Keyboard enhancement flags

## Usage

This is a simple example how to get started with the package.

```dart
final parser = Parser();
// ESC [ 20 ; 10 R
parser.advance([0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52]);
assert(parser.hasEvents, 'has events');
assert(parser.nextEvent() == const CursorPositionEvent(20, 10), 'retrieve event');
assert(!parser.hasEvents, 'no more events');
```

### Stream Processing

Use `eventTransformer` to convert byte streams to events:

```dart
stdin.transform(eventTransformer<KeyEvent>())
  .listen((event) => print('Key: $event'));
```

## Event Hierarchy

Events are organized into semantic categories for type-safe filtering:

- **InputEvent** - User-generated input (keyboard, mouse, paste)
  - `KeyEvent`, `MouseEvent`, `PasteEvent`, `RawKeyEvent`

- **ResponseEvent** - Terminal responses to queries
  - `CursorPositionEvent`, `ColorQueryEvent`, `FocusEvent`
  - `PrimaryDeviceAttributesEvent`, `KeyboardEnhancementFlagsEvent`
  - `QuerySyncUpdateEvent`, `QueryTerminalWindowSizeEvent`
  - `NameAndVersionEvent`, `ClipboardCopyEvent`, `UnicodeCoreEvent`

- **ErrorEvent** - Parser/engine errors
  - `EngineErrorEvent`

- **InternalEvent** - Parser-internal events
  - `NoneEvent`

### Filtering Events

Use `whereType<T>()` to filter events by category:

```dart
final parser = Parser()
  ..advance([0x61]) // 'a' key
  ..advance([0x1B, 0x5B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x52]); // Cursor position

final events = parser.drainEvents();

// Filter only user input
final inputs = events.whereType<InputEvent>();

// Filter only terminal responses
final responses = events.whereType<ResponseEvent>();

// Filter specific event types
final keyEvents = events.whereType<KeyEvent>();
```

## Acknowledgements

This package is _**strongly influenced**_ by the following projects:

- [annes](https://github.com/qwandor/anes-rs)
- [vaxis](https://git.sr.ht/~rockorager/vaxis)

## License

`termparser` is licensed under the [MIT license](LICENSE).
