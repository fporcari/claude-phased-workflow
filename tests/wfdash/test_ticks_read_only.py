#!/usr/bin/env python3
"""Phase 3 contract: the dashboard reads the Verify: steps, it records nothing.

A `Verify: now` step gates the close in interactive mode, and the gate is the
human's ok in the conversation (`refs/phase-execution.md`). The QA page's own
checkboxes are deliberately client-side and report nothing back
(`refs/contracts.md`). The delivered dashboard instead PERSISTED ticks to
`~/.claude/wfdash/<slug>/checks.json`, where no skill reads them: a durable
second source of truth for a gate, which is worse than none.

So the writing half goes and the parser stays.

Four things are asserted:

  - the write endpoint is gone, and gone from the write list too;
  - the one path wfdash WROTE under `~/.claude/` is gone, while the three it
    READS stay: the transcripts, the agents' todo lists and the session
    records are what the dashboard is made of, and Phase 7 declares them as
    surfaces to watch. The prohibition is on writing there, not on reading;
  - the `Verify:` parser survives and still splits a step into its `when` and
    its text — that is the half the panel needs;
  - the page renders no checkbox for a check.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WFDASH = ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'
sys.path.insert(0, str(WFDASH))
import checks  # noqa: E402
import core  # noqa: E402
import inbox  # noqa: E402
import server  # noqa: E402

# --- the write endpoint is gone -------------------------------------------

assert '/api/check' not in server.WRITE_PATHS, \
    '/api/check is still declared as a write endpoint'
assert not hasattr(server.Handler, 'check'), 'the check handler survives'
for gone in ('set_check', 'checks_path', 'read_checks', 'check_id', 'ROOT'):
    assert not hasattr(checks, gone), f'checks.{gone} is part of the writing half'
print('test_ticks_read_only: the write endpoint is gone ok')

# --- the written path is gone, the read paths stay ------------------------

for src in sorted(WFDASH.glob('*.py')):
    text = src.read_text()
    assert "'wfdash'" not in text.replace("prefix='wfdash", "prefix='X"), \
        f'{src.name} still builds a path under ~/.claude/wfdash/'

assert core.PROJECTS.name == 'projects' and core.TASKS.name == 'tasks' \
    and inbox.SESSIONS.name == 'sessions', \
    'the three READ paths are what the dashboard is made of and must stay'
print('test_ticks_read_only: the written path is gone, the read paths stay ok')

# --- the parser stays -----------------------------------------------------

now = checks.WHEN_RE.match('now — open /foo and save a row')
assert now and now.group(1).lower() == 'now', 'the `now` form no longer parses'
assert 'open /foo' in now.group(2), now.group(2)

deferred = checks.WHEN_RE.match('deferred: needs Phase 5 — the total matches')
assert deferred and deferred.group(1).lower().startswith('deferred'), \
    'the `deferred` form no longer parses'
print('test_ticks_read_only: the Verify: parser survives ok')

# --- the page renders no checkbox for a check ----------------------------

PAGE = (WFDASH / 'index.html').read_text()
assert 'type="checkbox"' not in PAGE, \
    'the page still renders a checkbox: a tick that persists nowhere reads as a gate'
print('test_ticks_read_only: no checkbox in the page ok')

print('test_ticks_read_only ok')
