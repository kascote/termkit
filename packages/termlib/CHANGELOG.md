## 0.6.0

- breaking: `TermLib` replaced by sealed `Term`. `Term.open({TermBackend? backend})` returns `InteractiveTerm` (tty stdin) or `PipedTerm` (piped stdin); dispatch via pattern matching.
  - `poll<T>()` renamed to `tryEvent<T>()`, returns `T?` (no more `NoneEvent` sentinel).
  - `pollTimeout<T>({int timeout})` renamed to `awaitEvent<T>({Duration? timeout})`, returns `Future<T?>` (null on timeout).
  - `read<T>()` renamed to `nextEvent<T>()`, returns `Future<T>` (blocks until matched).
  - `stdinStream` renamed to `stdinBytes`, moved to `PipedTerm` only.
  - Runtime `hasTerminal` gates replaced by the sealed split: events, raw mode, cursor/erase extensions, probe and readline live on `InteractiveTerm` — piped misuse is a compile error.
  - `TermRunner` builds an `InteractiveTerm`; callbacks receive it typed.
  - `terminalOverrides` removed — tests inject `TermBackend.fake(...)` and capture output through a buffered `TermSink`.
- breaking: `Style` is immutable — `apply(TextStyle)` returns a new `Style` instead of mutating; added `copyWith` and `render(text, {reset})`; instances compare by value.
- breaking: the event queue is bounded (drop-oldest) — overflow surfaces as a `QueueOverflowEvent`; mouse-motion and resize events coalesce at enqueue.
- added: `withModes()` — scoped enable/restore of terminal modes (raw, alternate screen, mouse, kitty keyboard enhancement, bracketed paste, in-band resize, line wrap, cursor visibility), tracked in `TermModes`.
- added: `probe()` detects terminal capabilities and returns a `TermInfo`.
- added: `enableResizeEvents()` / `disableResizeEvents()` — in-band resize (mode 2048) with a SIGWINCH fallback that synthesizes `WindowResizeEvent` on terminals without the mode.
- added: `KeyBinding<A>` — declarative key-spec → action mapping (`'ctrl+a'`, aliases); handles kitty repeat events.
- added: color scheme support — `queryColorScheme()`, `enableColorPaletteUpdates()` / `disableColorPaletteUpdates()`; the terminal reports via `ColorSchemeEvent`.
- added: DECRQM status queries `queryBracketedPaste()` and `queryInBandResize()`.
- added: `flush()` — push pending output without close or exit.
- changed: readline gained emacs-style motions — end of line (`ctrl+e`), word left/right (`alt+b`/`alt+f`), delete word (`alt+d`, `alt+backspace`, `ctrl+w`), transpose (`ctrl+t`), yank (`ctrl+y`), clear screen (`ctrl+l`).
- changed: the `noColor` profile keeps text attributes (bold, reverse, underline, …) and drops only colors, per no-color.org.
- fixed: color downsampling accuracy — RGB→256 quantizes to the nearest color-cube level and considers the grayscale ramp; nearest-color matching runs in OKLab, so desaturated colors no longer land on the wrong hue.

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
