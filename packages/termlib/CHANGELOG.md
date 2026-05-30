## unreleased

- breaking change (Phase 2 — API shape):
  - `TermLib` replaced by sealed `Term` with factory `Term.open({TermBackend? backend})` returning `InteractiveTerm` (tty stdin) or `PipedTerm` (piped stdin). Users dispatch via pattern matching.
  - `poll<T>()` renamed to `tryEvent<T>()` and now returns `T?` (no more `NoneEvent` sentinel).
  - `pollTimeout<T>({int timeout})` renamed to `awaitEvent<T>({Duration? timeout})`, returns `Future<T?>` (null on timeout).
  - `read<T>()` renamed to `nextEvent<T>()`, returns `Future<T>` (blocks forever, non-null).
  - `stdinStream` renamed to `stdinBytes` and moved to `PipedTerm` only.
  - Runtime `hasTerminal` gates replaced by the sealed split: `events`, `tryEvent`, `nextEvent`, `awaitEvent`, raw mode, cursor/erase extensions, probe and readline now live on `InteractiveTerm` — piped misuse is a compile error.
  - `TermRunner` builds an `InteractiveTerm`; callbacks receive it typed.
- added: probe to check terminal capabilities and return TermInfo
- added: OSC 9;4 - to set Progress bar
- added: CSI ? 2031 h/l - Enable/Disable Color Scheme event changes
- added: CSI ? 2048 h/l - Enable/Disable in band resize events
- added: CSI ? 2048 - query in band resize support

## 0.5.0

- breaking change
  - changed how reset styles works. Now need explicit reset.
  - refactored Color class, updated examples, tests, etc.
  - export from color_util only what is needed, try to minimize public API surface.
  - readline: changed how to handle escape key (now returns null instead of throwing)
- updated: removed unused methods from FFI interface
- added: query functions for 2027 (Unicode Core)
- added: implements disable individual styles (bold off, italic off, etc)
- added: expose events controllers directly

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
