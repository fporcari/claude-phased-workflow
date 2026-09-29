#!/usr/bin/env python3
"""wfdash inbox: who the foreman is, resolved from the plan and nothing else.

The socket writers left with the server's authority over the work — the
delivery belongs to `refs/foreman.md` now — so what is left to assert is the
resolution the dashboard still does before it queues a request:

  - the target is the title `foreman.json` names: no foreman, a foreman whose
    chat is not running, and a live one are three distinct answers;
  - the title beats every other chat in the list, whatever its position;
  - an assisted plan has no foreman: it is refused even when a stale
    `foreman.json` names a live chat; a manual plan has one, like an
    autonomous plan.

No live session is read and none is written to.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import inbox  # noqa: E402

PID = 4242
TITLE = 'wf:a-slug:foreman'
plan = {'mode': 'autonomous', 'foreman': {'foreman': TITLE}}
live = {'name': TITLE, 'live': True, 'pid': PID, 'session_id': 'stub'}
dead = {'name': TITLE, 'live': False, 'pid': None, 'session_id': 'stub'}

assert 'error' in inbox.foreman_target({'mode': 'autonomous', 'foreman': None}, [live])
stale = dict(plan, mode='assisted')
assert inbox.foreman_target(stale, [live])['error'] == inbox.NO_FOREMAN
assert inbox.mirror('.', stale, [live])['error'] == inbox.NO_FOREMAN
assert inbox.foreman_target(dict(plan, mode='manual'), [live])['pid'] == PID
assert inbox.foreman_target(plan, [])['error'].endswith('it is gone')
assert 'not running' in inbox.foreman_target(plan, [dead])['error']
assert inbox.foreman_target(plan, [{'name': 'other'}, live])['pid'] == PID
assert inbox.foreman_chat(plan, [dead]) == (TITLE, dead)

print('test_inbox ok')
