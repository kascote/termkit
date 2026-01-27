### unreleased

- added: OSC 9;4 - to set Progress bar
- added: CSI ? 996 n - Color Scheme Reporting
- added: CSI ? 2031 h/l - Enable/Disable Color Scheme event changes

### 0.4.0

- added: CSI 2027 - unicode core
- added: CSI 2024 - bracketed paste mode
- refactor: Changed ansiHex and x11Colors to use integers instead of strings
  to avoid conversion BREAKING CHANGE
- refactored: changes field definitions to const
- feat: added assertions to improve development issues detection
- fix: fixed disableMousePixelsEvents definition
- refactor: unify multiple functions to reset underlines under resetUnderlineStyle
- refactor: renamed trueColor() to trueColorFg() for consistency BREAKING CHANGE

## 0.3.1

- fixed analysis warnings
- updated dependencies

## 0.3.0

- added: text style attributes

## 0.2.0

- added: CSI!p - Soft terminal reset
- added: CSI14t - Read terminal size in pixels
- added: OSC52 - clipboard support

## 0.1.1

- Comply with pub.dev analysis

## 0.1.0

- Initial version.
