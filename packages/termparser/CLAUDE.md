# Overview

ANSI Terminal escape sequence parser.

## Architecture

### Two-Stage Design

Flow: `Bytes → Engine → SequenceData → Parser → Events → EventQueue`

### Key Concepts

VT500-series state machine (`lib/src/engine/engine.dart`) with states: `ground`, `escape`, `escapeIntermediate`, `csiEntry`, `csiIgnore`, `csiParameter`, `csiIntermediate`, `textBlock`, `textBlockFinal`, `oscEntry`, `oscParameter`, `oscFinal`, `dcsEntry`, `dcsIgnore`, `utf8`.

**SequenceData** (`lib/src/engine/sequence_data.dart`):
Intermediate representation between Engine and Parser. Types: CharData, CsiSequenceData, OscSequenceData, DcsSequenceData, TextBlockSequenceData, ErrorSequenceData.

**Event Hierarchy** (`lib/src/events/event_base.dart`):

- `InputEvent` - User input (keyboard, mouse, paste)
- `ResponseEvent` - Terminal responses (cursor position, colors, device attributes)
- `ErrorEvent` - Structural parsing errors
- `InternalEvent` - Parser internals

**Parser API**:

- `advance(List<int> buffer, {bool hasMore})` - Feed bytes to engine
  - `hasMore` flag critical: distinguishes ESC key press vs ESC sequence start
- `nextEvent()` / `peekEvent()` / `drainEvents()` - Retrieve events
- `eventTransformer<T>()` - StreamTransformer for byte streams

### Important Patterns

**hasMore flag**: When `hasMore=false` and byte is ESC (0x1b), it's treated as ESC key press. When `hasMore=true`, engine waits for next byte to determine if it's a sequence.

**Bracketed paste**: Engine tracks `_inTextBlock` flag. CSI 200~ starts block, CSI 201~ ends it. Content stored raw in `_sequenceBytes`, extracted using offsets.

**Parameters**: Engine uses `ParameterAccumulator` during parsing, converts to immutable `Parameters` when emitting SequenceData.

### Adding New CSI Response Events

1. **Add event** in `lib/src/events/response_events.dart`:
   - For enum-based responses, add enum first then event class
   - Pattern: `FooEvent extends ResponseEvent` with `code` field + derived `status`/`mode`
   - Implement `==`, `hashCode`

2. **Add parser** in `lib/src/parsers/csi_parser.dart`:
   - Add case to `parseCSISequence()` switch (final char, e.g., `'n'`, `'y'`, `'t'`)
   - Add `_parseFoo(Parameters params)` function using pattern matching.
     Parsers return `Event?` — return `null` for no-match:

   ```dart
   Event? _parseFoo(Parameters params) {
     switch (params.values) {
       case ['997', ...]:  // discriminator
         return FooEvent(int.tryParse(params.values[1]) ?? 0);
       default:
         return null;
     }
   }
   ```

3. **Add tests**:
   - `test/response_events_test.dart` - event unit tests (constructor, equality, hashCode)
   - `test/parsers_test.dart` - parser integration tests using `keySequence('π[...')`

### Adding New OSC Response Events

Similar pattern but in `lib/src/parsers/osc_parser.dart`. OSC sequences use `π]code;data π\\` format.

## Testing

**Convention**: π symbol represents ESC (0x1b) for readability:

```dart
keySequence('πOR')  // Means ESC O R
```

### DEC ANSI conformance

`test/conformance/dec_ansi_conformance_test.dart` checks the Engine cell-by-cell
against the canonical DEC parser state machine (vt100.net/emu/dec_ansi_parser),
extracted to `specs/dec_ansi/` (JSON spec, human-readable doc, Python oracle).
Input-side departures from DEC (ESC-key disambiguation, colon subparameters,
flattened DCS header, no SOS/PM/APC, …) are pinned in the test's `deviations`
registry, each tagged with a reason. When Engine behaviour changes on purpose,
update the registry entry — an unexplained mismatch on either side is a failure.

### Fuzzing

The generative fuzz harnesses (`test/fuzz/harnesses/`) are **opt-in**: their heavy
loops are skipped under a plain `dart test` / `make test` to keep the default suite
fast. They run only when a knob env var is set — use the dedicated targets:

```bash
make fuzz                 # iter-bounded (FUZZ_ITER, default 10000)
make fuzz ITER=300        # quick run
make fuzz-time SECS=60    # time-bounded (FUZZ_SECS)
make fuzz-replay          # replay persisted crashes/ only (regression guard)
make fuzz-corpus          # seed corpus only
```

The fast guards (`replay crashes/`, explicit seeds, `corpus_test.dart`) still run on
the default suite.
