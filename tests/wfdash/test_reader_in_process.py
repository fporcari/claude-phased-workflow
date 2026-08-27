#!/usr/bin/env python3
"""Phase 6 contract: the plan reader is loaded once, not spawned per read.

`selection()` ran `next-phase.py` as a fresh interpreter on every call — 28 ms
measured — and `server.py` has five `read_plan` sites on a page that polls every
five seconds. The reader stays the single one it is; only the way it is invoked
changes: `importlib` loads the file once despite the hyphen in its name, which
`import` cannot.

What must NOT change is the degradation. Every caller of `selection()` treats
`None` as "no plan" and answers that, and losing it is how a plan that cannot be
read would start answering 500 instead.

Three things are asserted:

  - a read succeeds with the subprocess machinery made unusable — the proof that
    nothing is spawned, and that no later read falls back to spawning;
  - twenty consecutive reads all succeed under the same condition, so the module
    is cached rather than reloaded through the old road;
  - a plan that cannot be read still yields None.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402

PLAN = """# Context: wf/toy
Parent: main
Mode: autonomous

## Objective
Toy.

## Work Plan
- [ ] **Phase 1**: one
  - Done: a
"""


def no_subprocess(*a, **k):
    raise AssertionError('selection() spawned a process')


real_run = core.subprocess.run
core.subprocess.run = no_subprocess
try:
    sel = core.selection(text=PLAN)
    assert sel is not None, 'the reader refused a well-formed plan in-process'
    assert [ph['n'] for ph in sel['phases']] == [1], \
        f'the in-process read returned the wrong phases: {sel["phases"]}'
    print('test_reader_in_process: a read spawns no process ok')

    for i in range(20):
        again = core.selection(text=PLAN)
        assert again is not None, f'read {i} fell back to spawning'
    print('test_reader_in_process: twenty reads spawn no process ok')

    missing = core.selection(path=pathlib.Path('/nonexistent/plan.md'))
    assert missing is None, \
        f'a plan that cannot be read did not degrade to None: {missing}'
    print('test_reader_in_process: an unreadable plan still yields None ok')
finally:
    core.subprocess.run = real_run

print('test_reader_in_process ok')
