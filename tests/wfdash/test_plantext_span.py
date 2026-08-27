#!/usr/bin/env python3
"""Phase 5 contract: the plan format has one reader, and it reports line spans.

`server.py` carried its own `PHASE_LINE` / `BLOCK_END` pair to slice a phase's
block out of plan.md — a second implementation of the plan format, which S18
exists to forbid and could not see: its guard misses a regex whose marker is
written escaped (`\\*\\*Phase`). Widening the guard flags this slicer, so the
slicer goes: `next-phase.py --json` reports each phase's line span and
`plantext` cuts by numbers.

The span is 1-based and INCLUSIVE, and it reproduces byte-for-byte what the old
slicer returned: from the phase's marker line through the line immediately
before the next marker or the next `## ` heading — the trailing blank line
included, because that is where the old boundary fell.

Four things are asserted:

  - every phase in the payload carries a span, and the payload a header span;
  - the spans of a known plan are the known numbers;
  - slicing the text by a span yields the phase's own block, marker line first;
  - `server` no longer holds a marker regex of its own.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402
import server  # noqa: E402

#  1  # Context: wf/toy
#  2  Parent: main
#  3  Mode: autonomous
#  4
#  5  ## Objective
#  6  Toy.
#  7
#  8  ## Work Plan
#  9  - [ ] **Phase 1**: one
# 10    - Done: a
# 11  - [ ] **Phase 2**: two
# 12    - Done: b
# 13
# 14  ## Notes
# 15  - a note
PLAN = """# Context: wf/toy
Parent: main
Mode: autonomous

## Objective
Toy.

## Work Plan
- [ ] **Phase 1**: one
  - Done: a
- [ ] **Phase 2**: two
  - Done: b

## Notes
- a note
"""
LINES = PLAN.splitlines()

sel = core.selection(text=PLAN)
assert sel is not None, 'the reader refused a well-formed plan'

# --- every phase carries a span, the payload a header span ----------------

assert 'header_span' in sel, 'the payload carries no header_span'
for ph in sel['phases']:
    assert 'span' in ph, f"phase {ph['n']} carries no span"
    first, last = ph['span']
    assert isinstance(first, int) and isinstance(last, int), \
        f"phase {ph['n']}'s span is not a pair of line numbers: {ph['span']}"
    assert 1 <= first <= last <= len(LINES), \
        f"phase {ph['n']}'s span is outside the text: {ph['span']}"
print('test_plantext_span: every phase carries a span ok')

# --- the spans of a known plan are the known numbers ---------------------

spans = {ph['n']: tuple(ph['span']) for ph in sel['phases']}
assert spans == {1: (9, 10), 2: (11, 13)}, \
    f'the spans moved: {spans} — expected {{1: (9, 10), 2: (11, 13)}}'
assert tuple(sel['header_span']) == (1, 7), \
    f"the header span moved: {sel['header_span']} — expected (1, 7)"
print('test_plantext_span: the spans of a known plan are the known numbers ok')

# --- slicing by a span yields the phase's own block ----------------------

for n, (first, last) in spans.items():
    block = LINES[first - 1:last]
    assert block[0].startswith(f'- [ ] **Phase {n}**'), \
        f'the span of phase {n} does not open on its marker line: {block[:1]}'
    assert not any(ln.startswith('- [ ] **Phase') for ln in block[1:]), \
        f'the span of phase {n} runs into the next phase: {block}'
header = LINES[sel['header_span'][0] - 1:sel['header_span'][1]]
assert 'Mode: autonomous' in header, f'the header span lost the Mode line: {header}'
assert not any(ln.startswith('## Work Plan') for ln in header), \
    f'the header span runs into the Work Plan: {header}'
print('test_plantext_span: a span yields the phase block, marker line first ok')

# --- the server holds no marker regex of its own ------------------------

for gone in ('PHASE_LINE', 'BLOCK_END'):
    assert not hasattr(server, gone), \
        (f'server.{gone} is still there: the plan format has two readers again')
print('test_plantext_span: the server holds no marker regex of its own ok')

print('test_plantext_span ok')
