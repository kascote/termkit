## 0.5.0

- breaking: `toSpec()` folds shift into the produced character for char-kind keys ('A', '!'); named keys keep explicit modifiers; new `KeyCode.shiftProduced` flag marks kitty alternate shifted keys
- breaking: CapsLock/NumLock state bits (64/128) no longer reported as held modifiers (bit 128 was mislabeled keyPad); lock state is parsed and dropped
- breaking: parser functions return `Event?`; the `NoneEvent` sentinel is gone, fixing its leak to the public queue on unhandled CSI finals
- added: `KeyEvent.text` — the kitty CSI-u typed-text parameter, on presses and repeats, never on releases
- added: ColorSchemeEvent to report terminal color scheme (CSI 997)
- added: InBandResizeEvent to report terminal resize in band (CSI 2048)
- added: parser for DA2 (secondary device attributes)
- added: query and probe support for bracketed paste
- changed: color query events keep the query and index flags
- added: DEC ANSI conformance suite against the vt100.net state machine, with a reasoned deviations registry (`specs/dec_ansi/`)
- added: fuzz test suite (stream / structured / utf8 harnesses) with seed corpus, crash dump + replay regression guard, and naive shrinker (see `specs/FUZZ_PLAN.md`)
- fixed: SGR mouse motion with a button held now reports `drag` instead of `moved` (drags were undetectable; `MouseButtonAction.drag` was unreachable)
- fixed: malformed CSI sequences are consumed to the final byte instead of replaying their remainder as input (a phantom-keypress injection vector)
- fixed: OSC string bytes 0x20-0x2E accumulated instead of dropped
- fixed: DCS header params accumulated; hook passthrough at 0x40-0x7E
- fixed: CAN/SUB cancel the in-flight sequence and deliver the control byte
- fixed: SOS/PM/APC strings are swallowed instead of replaying their bodies as input
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
