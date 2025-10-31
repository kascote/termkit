## unreleased

- breaking change
  - changed how reset styles works. Now need explicit reset.
  - refactored Color class, updated examples, tests, etc.
  - export from color_util only what is needed, try to minimize public API surface.
  - readline: changed how to handle escape key (now returns null instead of throwing)
- updated: removed unused methods from FFI interface
- added: query functions for 2027 (Unicode Core)
- added: implements disable individual styles (bold off, italic off, etc)

## 0.4.0

- updated: updated test cases/coverage
- updated: keyboard handling
- updated: export Style profile
- updated: rgb distance function
- new: added underline styles
- new: example to check luminance (dart/light)

## 0.3.0

- added: more text styles, support curly underline with color

## 0.2.1

- fixed: packages dependencies

## 0.2.0

- added: request terminal window size in pixels query
- added: soft terminal reset
- added: clipboard handling support

## 0.1.1

- Comply with pub.dev analysis

## 0.1.0

- Initial version.
