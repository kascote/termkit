# Overview

`termansi` is a Dart package providing ANSI escape sequence definitions for terminal applications. This is a reference library - it defines constants and helper functions without additional functionality.

## Architecture

### Core Structure

- `lib/src/escape_codes.dart` - Base escape sequence constants (ESC, CSI, OSC, etc.)
- All other modules in `lib/src/` build on these base codes
- Main export file: `lib/termansi.dart` re-exports all modules

### Modules

- **colors.dart** - Standard/bright colors (fg/bg), 256-color, true color support
- **cursor.dart** - Cursor movement, positioning, visibility, styles (CursorStyle enum)
- **term.dart** - Terminal features (alternate screen, mouse events, keyboard protocol, clipboard, sync updates, hyperlinks)
- **text.dart** - Text styling attributes (bold, italic, underline, etc.)
- **erase.dart** - Screen/line clearing operations
- **ansi_hex.dart** - Hex color utilities
- **x11_colors.dart** - X11 color name definitions

### Adding New Sequences

**Naming conventions**:

- Query sequences: `queryXxx` (e.g., `queryColorScheme`, `queryPrimaryDeviceAttributes`)
- Enable/disable pairs: `enableXxx`/`disableXxx`
- Static methods for parameterized sequences, `const String` for fixed sequences
