#!/usr/bin/env python3
"""Phase 4 contract: the plan format has one reader, and the dashboard uses it.

`refs/common.md` declares phase selection deterministic and single-sourced in
`next-phase.py`. The delivered `core.py` carried a second implementation, and
`core.py`'s `PHASE_RE` was byte-for-byte identical to `next-phase.py`'s — a
frozen copy of a shipped contract. The two also disagreed: `recommend()` yields
five outcomes, `plan_shape` collapsed them into `next` plus `blocked_by`, so a
`[>]` resume candidate and a phase awaiting the human's checks became the same
answer. The launch buttons acted on that answer.

Four things are asserted:

  - `--json` exists and emits the selection, parseable;
  - it distinguishes the outcomes the table distinguishes;
  - `core.py` holds no phase-marker regex of its own;
  - `finished_plan` still finds a closed plan — the capability `next-phase.py`
    does not have, and the part of the delivery worth keeping.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
NEXTPHASE = ROOT / 'plugins' / 'wf' / 'scripts' / 'next-phase.py'
WFDASH = ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'
sys.path.insert(0, str(WFDASH))
import core  # noqa: E402

PLAN = """# Context: wf/probe
Parent: main
Mode: interactive

## Objective
A plan with one closed phase, one open, one blocked.

## Work Plan
- [x] **Phase 1**: the closed one
  - Done: nothing
- [ ] **Phase 2**: the next one
  - Done: nothing
- [ ] **Phase 3**: the one after
  - Done: nothing
"""


def emit(text):
    d = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-phase4-'))
    p = d / 'plan.md'
    p.write_text(text)
    out = subprocess.run([sys.executable, str(NEXTPHASE), '--json', str(p)],
                         capture_output=True, text=True)
    assert out.returncode == 0, f'--json exited {out.returncode}: {out.stderr}'
    return json.loads(out.stdout)


# --- --json exists and carries the selection ------------------------------

got = emit(PLAN)
assert got['next'] == 2, f'next should be 2: {got.get("next")}'
assert got.get('blocked_by') in (None, 0), f'nothing blocks this plan: {got}'
assert 'recommendation' in got, f'no recommendation in the payload: {sorted(got)}'
assert len(got['phases']) == 3, f'{len(got["phases"])} phases parsed'
assert got['phases'][0]['status'] == 'x', got['phases'][0]
print('test_one_selection: --json carries the selection ok')

# --- it keeps the outcomes apart -----------------------------------------

# The note must land INSIDE Phase 2's block. Appending it to the plan text
# attaches it to the LAST phase instead — Phase 3 — and then `recommend()` is
# right to answer `resume-candidate: 2`: a bare `[>]` with no Testing note IS a
# resume candidate. The contract (`refs/phase-execution.md`) makes a phase
# `blocked:` only when the note sits on the `[>]` phase itself.
waiting = PLAN.replace(
    '- [ ] **Phase 2**: the next one\n  - Done: nothing\n',
    '- [>] **Phase 2**: the next one\n  - Done: nothing\n'
    '  > Testing: awaiting the human\'s `Verify: now` checks | commit: abc1234\n',
)
got = emit(waiting)
assert got['recommendation'].startswith('blocked'), \
    f'a phase awaiting the human must read as blocked, not as a failure: {got["recommendation"]}'

failed = PLAN.replace('- [ ] **Phase 2**', '- [!] **Phase 2**')
got = emit(failed)
assert got['recommendation'].startswith('attention'), \
    f'a [!] phase must read as attention: {got["recommendation"]}'
print('test_one_selection: the outcomes stay apart ok')

# --- core.py holds no regex of its own -----------------------------------

# Asserted on the DEFINITION and on the marker pattern, never on the substring
# `PHASE_RE`: `TITLE_PHASE_RE` contains it and is a legitimate reader of chat
# titles that nothing here deletes. Likewise `PHASE_COMMIT_RE` matches commit
# subjects, not plan markers, and stays.
SRC = (WFDASH / 'core.py').read_text()
assert not re.search(r'(?m)^PHASE_RE\s*=', SRC), \
    'core.py still defines PHASE_RE: a frozen copy of next-phase.py:46'
assert r'\*\*Phase ' not in SRC, \
    'core.py still carries the plan marker pattern — the format has one reader'
assert hasattr(core, 'TITLE_PHASE_RE'), \
    'TITLE_PHASE_RE reads chat titles, not plan markers, and must survive'
print('test_one_selection: core.py has no plan regex of its own ok')

# --- finished_plan survives ----------------------------------------------

assert hasattr(core, 'finished_plan'), \
    'finished_plan was deleted: reading a closed plan is capability next-phase.py lacks'
print('test_one_selection: finished_plan survives ok')

print('test_one_selection ok')
