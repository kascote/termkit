# TermAnsi

Pure Dart ANSI escape sequence reference library. Provides constants and helpers for terminal colors, cursor control, text styling, and advanced terminal features.

Part of [TermKit](https://github.com/kascote/termkit).

## Installation

```yaml
dependencies:
  termansi: ^0.3.1
```

## Quick Start

```dart
import 'package:termansi/termansi.dart';

// Colors
print('${Color.red}Error${Color.reset}');
print('${Color.color256Fg(42)}Custom${Color.reset}');
print('${Color.rgbFg(255, 100, 50)}RGB${Color.reset}');

// Text styling
print('${Text.bold}Important${Text.resetBold}');
print('${Text.italic}Emphasis${Text.resetItalic}');

// Cursor control
stdout.write(Cursor.moveTo(10, 20));
stdout.write(Cursor.hide);
```

## Features

- **Colors**: ANSI/256/truecolor (fg/bg)
- **Cursor**: Movement, positioning, visibility
- **Text**: Bold, italic, underline, strikethrough
- **Terminal**: Alternate screen, mouse events, keyboard protocol
- **Erase**: Screen/line clearing
- **X11 colors**: Named color support

**Examples:**
- [termansi_example.dart](example/termansi_example.dart) - Basic usage
- [advanced_example.dart](example/advanced_example.dart) - Terminal features (mouse, keyboard, clipboard, alt screen)

## API Overview

All features exposed via static classes:
- `Color` - Foreground/background colors
- `Text` - Styling attributes
- `Cursor` - Cursor operations
- `Term` - Terminal features (mouse, keyboard, clipboard, hyperlinks)
- `Erase` - Clear operations

## License

MIT - see [LICENSE](LICENSE)
