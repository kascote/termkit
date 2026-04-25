## unreleased

- added: ColorSchemeEvent to report terminal color scheme (CSI 997)
- added: InBandResizeEvent to report terminal resize in band (CSI 2048)
- added: fuzz test suite (stream / structured / utf8 harnesses) with seed corpus, crash dump + replay regression guard, and naive shrinker (see `specs/FUZZ_PLAN.md`)
- fixed: NoneEvent leak to public queue on unhandled CSI finals
- fixed: FormatException on malformed UTF-8 (allowMalformed in utf8 decoder)
- fixed: FormatException on non-numeric CSI params (int.tryParse in csi/key parsers)
- fixed: base64Decode crash on malformed OSC 52 clipboard payload
- fixed: `_inTextBlock` leak past DCS termination causing RangeError on later paste close
- fixed: RangeError on UTF-8 BOM (empty decode forwarded to ctrlOrKey)
- added: `@visibleForTesting` getters on Engine (sequenceByteCount, paramCount, inTextBlock)

## 0.4.0

- fixed: event filter for eventTransformer
- added: helper functions to check for single key modifiers
- added: parser support for CSI 2027 Unicode Core
- added: debug capability to be more easy to trace parsing issues
- refactor: simplify provider parser with an eventQueue
- refactor: content blocks handle to unify for example bracketed paste and text content (terminal version)

## 0.3.0

- added: QueryTerminalWindowSizeEvent to return window size event
- added: ClipboardCopyEvent to return clipboard content

## 0.2.0

- fixed: fixed OSC10 parsing

## 0.1.1

- Comply with pub.dev analysis

## 0.1.0

- Initial version.
