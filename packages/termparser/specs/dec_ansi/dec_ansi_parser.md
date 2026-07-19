# DEC ANSI parser — state machine, extracted

Extracted 2026-07-19 from Paul Flo Williams, *A parser for DEC's ANSI-compatible
video terminals* (<https://vt100.net/emu/dec_ansi_parser>, published 2002-03-11,
last modified 2017-08-25, CC BY 4.0). The transition data was parsed out of the
page's inline SVG state diagram (whose element ids name every edge:
`legend-<src>-to-<dst>`) and the State/Action Definitions prose, then verified
complete + deterministic and diffed byte-for-byte against
[haberman/vtparse](https://github.com/haberman/vtparse) — the C implementation
the page endorses. Zero mismatches.

**Scope.** This is the *terminal-side* parser: the byte stream a host sends to a
DEC VT220–VT525. Events are single bytes in hex. It predates UTF-8 and models
8-bit single-byte encodings only.

Machine-readable version: `dec_ansi_parser.json`.
Executable reference: `dec_ansi_oracle.py` (`verify` / `table` / `trace` / `diff-vtparse`).

## How to read the machine

- **Initial state:** `ground`.
- **Internal events** (listed per state under *Events*) fire their action and
  stay in the state. No entry/exit actions run.
- **Transitions** run, in order: the old state's **exit** action → the
  **transition** action → the new state's **entry** action.
- **Anywhere rules** apply from *every* state and take precedence; a transition
  that lands on the current state still runs exit-then-entry.
- **GR = GL:** bytes `A0–FF` behave exactly like `20–7F` (look up `byte − 0x80`,
  hand the original byte to the action). This does *not* extend to C0/C1.

## Actions

| Action | Meaning |
|---|---|
| `ignore` | Drop the byte; no observable effect. |
| `print` | Ground only: map byte through charset/shift state, display glyph. |
| `execute` | Execute the C0/C1 control function immediately (no parameters). |
| `clear` | Forget private marker, intermediates, final, params. Entry to `escape`, `csi_entry`, `dcs_entry`. |
| `collect` | Store private marker (`3C–3F`) / intermediate (`20–2F`) for the dispatch. >2 intermediates ⇒ flag so dispatch no-ops. |
| `param` | `30–39` extend current parameter, `3B` starts the next. Max 16 params (extras dropped); values ≥ 16383 supported, clamp above; empty and `0` both mean "default". |
| `esc_dispatch` | Escape sequence complete: pick function from intermediates + final, run it. |
| `csi_dispatch` | Control sequence complete: pick function from private marker + intermediates + final, run with params. |
| `hook` | DCS "header" complete: pick DCS function, select a data-string handler. Entry to `dcs_passthrough`. |
| `put` | Pass data-string byte (C0 included) to the hooked handler. |
| `unhook` | Data string ended (ST/CAN/SUB/ESC): tell handler "end of data". Exit of `dcs_passthrough`. |
| `osc_start` / `osc_put` / `osc_end` | Same shape for OSC strings: init handler on entry, stream bytes, close on exit (ST/CAN/SUB/ESC). |

## Anywhere (invariant, from every state)

| Bytes | Action | → |
|---|---|---|
| `18,1A` (CAN, SUB) | `execute` | `ground` |
| `80-8F,91-97,99,9A` (other C1) | `execute` | `ground` |
| `9C` (ST) | — | `ground` |
| `1B` (ESC) | — | `escape` |
| `90` (DCS) | — | `dcs_entry` |
| `98,9E,9F` (SOS, PM, APC) | — | `sos_pm_apc_string` |
| `9B` (CSI) | — | `csi_entry` |
| `9D` (OSC) | — | `osc_string` |

## States

### ground
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `20-7F` | `print` | – |

### escape — entry: `clear`
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `7F` | `ignore` | – |
| `20-2F` | `collect` | `escape_intermediate` |
| `30-4F,51-57,59,5A,5C,60-7E` | `esc_dispatch` | `ground` |
| `50` (P) | — | `dcs_entry` |
| `58,5E,5F` (X, ^, _) | — | `sos_pm_apc_string` |
| `5B` ([) | — | `csi_entry` |
| `5D` (]) | — | `osc_string` |

### escape_intermediate
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `20-2F` | `collect` | – |
| `7F` | `ignore` | – |
| `30-7E` | `esc_dispatch` | `ground` |

### csi_entry — entry: `clear`
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `7F` | `ignore` | – |
| `20-2F` | `collect` | `csi_intermediate` |
| `30-39,3B` | `param` | `csi_param` |
| `3C-3F` | `collect` | `csi_param` |
| `3A` | — | `csi_ignore` |
| `40-7E` | `csi_dispatch` | `ground` |

### csi_param
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `30-39,3B` | `param` | – |
| `7F` | `ignore` | – |
| `20-2F` | `collect` | `csi_intermediate` |
| `3A,3C-3F` | — | `csi_ignore` |
| `40-7E` | `csi_dispatch` | `ground` |

### csi_intermediate
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `20-2F` | `collect` | – |
| `7F` | `ignore` | – |
| `30-3F` | — | `csi_ignore` |
| `40-7E` | `csi_dispatch` | `ground` |

### csi_ignore
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `execute` | – |
| `20-3F,7F` | `ignore` | – |
| `40-7E` | — | `ground` |

### dcs_entry — entry: `clear`
C0 is *ignored* here (not executed), unlike the CSI states.
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F,7F` | `ignore` | – |
| `20-2F` | `collect` | `dcs_intermediate` |
| `30-39,3B` | `param` | `dcs_param` |
| `3C-3F` | `collect` | `dcs_param` |
| `3A` | — | `dcs_ignore` |
| `40-7E` | — | `dcs_passthrough` (entry `hook` fires) |

### dcs_param
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F,7F` | `ignore` | – |
| `30-39,3B` | `param` | – |
| `20-2F` | `collect` | `dcs_intermediate` |
| `3A,3C-3F` | — | `dcs_ignore` |
| `40-7E` | — | `dcs_passthrough` |

### dcs_intermediate
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F,7F` | `ignore` | – |
| `20-2F` | `collect` | – |
| `30-3F` | — | `dcs_ignore` |
| `40-7E` | — | `dcs_passthrough` |

### dcs_passthrough — entry: `hook`, exit: `unhook`
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F,20-7E` | `put` | – |
| `7F` | `ignore` | – |

Left only via *anywhere* (ST `9C`, ESC `1B`, CAN/SUB, any C1).

### dcs_ignore
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F,20-7F` | `ignore` | – |

Left only via *anywhere*.

### osc_string — entry: `osc_start`, exit: `osc_end`
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F` | `ignore` | – |
| `20-7F` | `osc_put` | – |

Left only via *anywhere*. Note: `07` (BEL) is in the *ignore* set — the VT500
does **not** end an OSC on BEL (xterm and every modern emulator does; see notes).

### sos_pm_apc_string
| Bytes | Action | → |
|---|---|---|
| `00-17,19,1C-1F,20-7F` | `ignore` | – |

Left only via *anywhere*.

## Behavioural notes from the prose

- **ESC cancels anything.** A control string ended by 7-bit ST (`1B 5C`)
  actually ends at the `1B` (the exit action fires there); the following `5C`
  dispatches ST, which is a no-op. No lookahead needed.
- **C0 interleaving is legal in CSI:** `CSI 2 LF C` executes the LF mid-sequence
  and still dispatches `CSI 2 C` (cursor two right, one down — VT100 error
  recovery that became folklore-standard).
- **CAN/SUB** cancel the sequence in progress; SUB also displays the error
  character (reversed question mark). VT220/VT420/VT500 behaviour; the VT320
  documented them as *not* cancelling.
- **Colon (`3A`)** anywhere in CSI params ⇒ the whole sequence is consumed but
  never dispatched (DEC's recovery for X3.64's "reserved" `3/10`).
- **Private markers `3C-3F`** are valid only as the first byte after CSI/DCS;
  DEC used only `=`, `>`, `?`.
- **Params:** 16 max, values to ≥ 16383, later params win on conflict
  (`CSI 7;0 m` leaves attributes off). Empty and `0` both select the default;
  keep them distinct internally (ECMA-48 distinguishes them).
- **NUL:** pre-VT500 terminals discarded `00` before parsing; the VT500 runs it
  through `execute` like any C0 (because of DECNULM).
- **SP/DEL in ground:** with a 94-char set in GL, `20` prints a space and `7F`
  is ignored; a 96-char set (VT320+, Latin-1) may print both.
- **OSC on real DECs** only carried DECSIN/DECSWT (VT520/525 icon name / window
  title); received SOS/PM/APC never meant anything (though VT420+ can *send*
  APC key reports).

## Using this against an implementation

1. `python3 dec_ansi_oracle.py verify` — self-check of the JSON (14 × 256
   cells, no gaps/overlaps).
2. `python3 dec_ansi_oracle.py table > table.tsv` — the fully expanded ground
   truth, one row per (state, byte): ordered actions + next state. Generate the
   same dump from your parser's tables and `diff`.
3. `python3 dec_ansi_oracle.py trace 1B 5B 33 6D` — reference action trace for
   any byte sequence. Drive your parser with the same bytes, record its
   callbacks (`print/execute/collect/param/…`), and compare traces. Fuzzing
   with random bytes and diffing traces gives you conformance for free.
4. `python3 dec_ansi_oracle.py diff-vtparse vtparse_tables.rb` — provenance
   check against the independent C implementation's tables
   (<https://github.com/haberman/vtparse>).

In this repo the machine is wired into the test suite:
`test/conformance/dec_ansi_conformance_test.dart` drives the termparser Engine
cell-by-cell against a Dart port of the oracle
(`test/conformance/dec_ansi_oracle.dart`, reading the JSON here). Intentional
input-side departures from DEC live in that test's `deviations` registry, each
tagged with its reason.
