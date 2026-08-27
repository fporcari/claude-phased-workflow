#!/usr/bin/env python3
"""wfdash checks: the Verify: steps of a phase, read from the plan.

Two things are asserted:

  - the steps of a phase are read with their `when`, and the `> Verify:` notes
    written by execution win over the `- Verify:` fields written by planning,
    so one check never appears twice;
  - the id carries the phase and the text, so the same wording in two phases
    differs and a reworded step is another step.

Nothing is written: the panel shows these steps and the ok is given in the
conversation, to /wf:close-phase.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import checks  # noqa: E402

AUTHORED = {
    'n': 4, 'status': ' ', 'title': 'a phase nobody has run', 'run': None,
    'notes': [],
    'verify': [{'text': 'now — the tree opens and closes'},
               {'text': 'deferred: needs Phase 8 — the full run reaches the grid'}],
}
EXECUTED = {
    'n': 5, 'status': 'x', 'title': 'a phase that ran', 'run': None,
    'notes': [{'kind': 'Review', 'text': 'the header carries a clock'},
              {'kind': 'Verify', 'text': 'now — done 2026-08-25: the owner read both'},
              {'kind': 'Verify', 'text': 'now — a tick survives a page reload'}],
    'verify': [{'text': 'now — the owner reads both instances'}],
}


def main():
    authored = checks.phase_checks(AUTHORED)
    assert [c['when'] for c in authored] == ['now', 'deferred: needs Phase 8'], authored
    assert authored[0]['text'] == 'the tree opens and closes'
    assert authored[1]['text'] == 'the full run reaches the grid'

    # the executed notes win: the authored field never doubles the list
    executed = checks.phase_checks(EXECUTED)
    assert len(executed) == 2, executed
    assert executed[0]['text'] == 'done 2026-08-25: the owner read both'
    assert all('the owner reads both instances' != c['text'] for c in executed)

    # the id carries the phase, and a rewording is another step
    assert authored[0]['id'].startswith('4:')
    reworded = dict(AUTHORED, verify=[{'text': 'now — the tree opens, and closes'}])
    assert checks.phase_checks(reworded)[0]['id'] != authored[0]['id']
    print('test_checks: ok')


if __name__ == '__main__':
    main()
