#!/usr/bin/env python3
"""Executable oracle for the DEC ANSI parser state machine (vt100.net/emu/dec_ansi_parser).

Loads dec_ansi_parser.json and provides:

  verify           check the machine is complete and deterministic:
                   every (state, byte 0x00-0xFF) resolves to exactly one rule
  table            emit the fully expanded transition table as TSV:
                   state <TAB> byte <TAB> ordered-actions <TAB> next-state
  trace HEX...     run bytes through the reference machine, print the action
                   trace (e.g. trace 1B 5B 33 38 3A 35 6D  or  trace '1B]0;hi\\x07')
  diff-vtparse F   compare against haberman/vtparse's vtparse_tables.rb

The trace output is the conformance contract: feed the same bytes to an
implementation, record its emitted actions, and diff.
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent


def parse_set(spec):
    """'00-17,19,1C-1F' -> sorted list of ints."""
    out = []
    for part in spec.split(','):
        if '-' in part:
            lo, hi = part.split('-')
            out.extend(range(int(lo, 16), int(hi, 16) + 1))
        else:
            out.append(int(part, 16))
    return out


class Machine:
    def __init__(self, spec):
        self.spec = spec
        self.states = list(spec['states'])
        # rule = (actions_before_move, next_state or None)
        self.anywhere = {}
        for t in spec['anywhere']:
            for b in parse_set(t['on']):
                assert b not in self.anywhere, f"anywhere overlap at {b:02X}"
                self.anywhere[b] = (t.get('action'), t['to'])
        self.local = {s: {} for s in self.states}
        for name, st in spec['states'].items():
            for ev in st.get('on', []):
                for b in parse_set(ev['on']):
                    self._add(name, b, ev.get('action'), None)
            for tr in st.get('transitions', []):
                for b in parse_set(tr['on']):
                    self._add(name, b, tr.get('action'), tr['to'])

    def _add(self, state, b, action, to):
        assert b not in self.local[state], f"{state}: duplicate rule for {b:02X}"
        assert b not in self.anywhere, f"{state}: {b:02X} overlaps an anywhere rule"
        self.local[state][b] = (action, to)

    def resolve(self, state, byte):
        """(state, byte) -> (action or None, next_state or None).

        next_state None means an internal event (no entry/exit actions fire).
        GR bytes A0-FF resolve like byte-0x80 but the action gets the real byte.
        """
        if byte in self.anywhere:
            return self.anywhere[byte]
        key = byte - 0x80 if 0xA0 <= byte <= 0xFF else byte
        rule = self.local[state].get(key)
        if rule is None:
            raise KeyError(f"{state}: no rule for byte {byte:02X}")
        return rule

    def step(self, state, byte):
        """Full observable semantics: ordered action list + new state."""
        action, to = self.resolve(state, byte)
        if to is None:
            return ([(action, byte)] if action else []), state
        acts = []
        exit_a = self.spec['states'][state].get('exit')
        if exit_a:
            acts.append((exit_a, None))
        if action:
            acts.append((action, byte))
        entry_a = self.spec['states'][to].get('entry')
        if entry_a:
            acts.append((entry_a, None))
        return acts, to

    def trace(self, data):
        state = self.spec['semantics']['initial_state']
        for byte in data:
            acts, new = self.step(state, byte)
            pretty = ', '.join(a if b is None else f"{a}(0x{b:02X})" for a, b in acts)
            move = '' if new == state else f"   => {new}"
            ch = chr(byte) if 0x20 <= byte < 0x7F else '.'
            yield f"  0x{byte:02X} {ch}  {pretty or '-'}{move}"
            state = new
        yield f"  final state: {state}"


def verify(m):
    problems = []
    for s in m.states:
        for b in range(0x100):
            try:
                m.resolve(s, b)
            except KeyError as e:
                problems.append(str(e))
    for t in m.spec['anywhere']:
        if t['to'] not in m.states:
            problems.append(f"anywhere targets unknown state {t['to']}")
    for name, st in m.spec['states'].items():
        for tr in st.get('transitions', []):
            if tr['to'] not in m.states:
                problems.append(f"{name} targets unknown state {tr['to']}")
    n = len(m.states) * 0x100
    if problems:
        print(f"FAIL: {len(problems)} problems")
        for p in problems:
            print(' ', p)
        return 1
    print(f"OK: {len(m.states)} states x 256 bytes = {n} cells, "
          f"each resolves to exactly one rule (no gaps, no overlaps)")
    return 0


def table(m):
    for s in m.states:
        for b in range(0x100):
            acts, new = m.step(s, b)
            names = '+'.join(a for a, _ in acts) or '-'
            print(f"{s}\t{b:02X}\t{names}\t{new if new != s else '.'}")


def diff_vtparse(m, path):
    src = Path(path).read_text()
    rng = re.compile(r'0x([0-9a-f]{2})(?:\.\.0x([0-9a-f]{2}))?\s*=>\s*(.+?),?$')
    tables = {}
    current = None
    for line in src.splitlines():
        line = line.strip()
        mm = re.match(r'\$states\[:(\w+)\]\s*=\s*\{', line)
        if mm:
            current = tables.setdefault(mm.group(1).lower(), {})
            continue
        if line.startswith('$anywhere_transitions = {'):
            current = tables.setdefault('__anywhere__', {})
            continue
        if line == '}':
            current = None
            continue
        if current is None:
            continue
        mm = rng.match(line)
        if not mm:
            continue
        lo = int(mm.group(1), 16)
        hi = int(mm.group(2), 16) if mm.group(2) else lo
        val = mm.group(3)
        action = None
        target = None
        am = re.search(r':(\w+)', val)
        tm = re.search(r'transition_to\(:(\w+)\)', val)
        if tm:
            target = tm.group(1).lower()
            am = re.match(r'\[?:(\w+)', val)
            action = am.group(1) if am and am.group(1) != 'transition_to' else None
        else:
            action = am.group(1) if am else None
        for b in range(lo, hi + 1):
            current[b] = (action, target)

    mism = 0
    anywhere = tables.pop('__anywhere__')
    for s in m.states:
        vt = tables.get(s, {})
        for b in range(0x00, 0xA0):  # vtparse tables leave A0-FF undefined
            ours = m.resolve(s, b)
            theirs = anywhere.get(b) or vt.get(b)
            if theirs is None:
                print(f"vtparse GAP     {s} {b:02X} (ours: {ours})")
                mism += 1
            elif (theirs[0], theirs[1]) != (ours[0], ours[1] if ours[1] else None):
                # internal event: our next None == their target None
                print(f"MISMATCH        {s} {b:02X} ours={ours} vtparse={theirs}")
                mism += 1
    extra = set(tables) - set(m.states)
    if extra:
        print(f"vtparse has extra states: {extra}")
        mism += 1
    print(f"{'OK: extraction matches vtparse' if not mism else f'{mism} mismatches'} "
          f"({len(m.states)} states x bytes 00-9F)")
    return 1 if mism else 0


def parse_bytes(argv):
    data = []
    for a in argv:
        if re.fullmatch(r'[0-9a-fA-F]{2}', a):
            data.append(int(a, 16))
        else:
            data.extend(a.encode('latin-1').decode('unicode_escape').encode('latin-1'))
    return bytes(data)


def main():
    m = Machine(json.loads((HERE / 'dec_ansi_parser.json').read_text()))
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'verify'
    if cmd == 'verify':
        sys.exit(verify(m))
    elif cmd == 'table':
        table(m)
    elif cmd == 'trace':
        for line in m.trace(parse_bytes(sys.argv[2:])):
            print(line)
    elif cmd == 'diff-vtparse':
        sys.exit(diff_vtparse(m, sys.argv[2]))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == '__main__':
    main()
