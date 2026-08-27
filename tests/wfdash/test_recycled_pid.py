#!/usr/bin/env python3
"""End to end: a chat presses, dies, and its pid comes back as another chat.

The whole ownership story in one run, against the real CLI and the real
handler — the pieces were each asserted apart, and the hole was between them.

  s-old presses a button   → the event is stamped (pid, s-old)
  s-old dies, the pid is recycled by s-new on the same repository
  s-new drains             → it must get NOTHING: the cwd check the ownership
                             rests on cannot tell s-new from s-old, and the
                             pid is identical
  s-new asks whether the leftover's owner is alive → `orphan`, because the
                             session ids differ, not the pids
  s-new recovers it explicitly (`--session s-old`) → served exactly once

The last step is the one that made `--session` necessary: with the pid alone,
the recovery resolves the LIVING session and rightly refuses the dead one's
event, which would then sit in the queue for ever.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'
sys.path.insert(0, str(HERE))
import inbox   # noqa: E402
import outbox  # noqa: E402
import server  # noqa: E402

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-recycled-'))
home = tmp / 'home'
sessions = home / '.claude' / 'sessions'
sessions.mkdir(parents=True)
repo = tmp / 'repo'
(repo / '.phased' / 'active' / 'rec').mkdir(parents=True)
(repo / '.phased' / 'active' / 'rec' / 'plan.md').write_text(
    '- [x] **Phase 1**: a\n- [ ] **Phase 2**: b\n')
inbox.SESSIONS = sessions
outbox.truncate(repo)

PID = 4242


def be(session_id):
    """The record the system shows for PID — one chat at a time."""
    (sessions / f'{PID}.json').write_text(json.dumps(
        {'cwd': str(repo), 'sessionId': session_id}))


def cli(*args):
    out = subprocess.run(
        [sys.executable, str(HERE / 'outbox.py'), '-C', str(repo), '--drain', *args],
        capture_output=True, text=True, check=True,
        env=dict(os.environ, HOME=str(home)))
    return json.loads(out.stdout)


class Fake:
    """The handler's own methods, with the one attribute they read."""

    launch = server.Handler.launch
    owner = server.Handler.owner
    owner_stamp = server.Handler.owner_stamp

    def __init__(self):
        self.board = type('B', (), {'repo': str(repo)})()

    def titles(self):                 # the board's chats, none in this fixture
        return {}


# --- s-old opens the dashboard and presses ----------------------------------

be('s-old')
granted = Fake().owner({'pid': PID})
assert 'error' not in granted, granted
assert server.Handler.owner_identity == (PID, 's-old'), server.Handler.owner_identity

answer = Fake().launch({'road': 'unattended'})
assert answer.get('queued') is True, answer
event = outbox.read(repo)[0]
assert (event['owner'], event['owner_session']) == (PID, 's-old'), event
print('test_recycled_pid: the press is stamped with the pair ok')

# --- s-old dies; the pid comes back as s-new --------------------------------

be('s-new')

served = cli('--pid', str(PID))
assert served['served'] == [], \
    f'the recycled pid inherited the dead chat\'s request: {served["served"]}'
assert [e['owner_session'] for e in served['remaining']] == ['s-old'], served
print('test_recycled_pid: the recycled pid is served nothing ok')

# --- and the liveness check says orphan, not live ---------------------------

leftover = served['remaining'][0]
live = inbox.owner_target(leftover['owner'], str(repo)) or {}
assert live.get('session_id') == 's-new', live
assert live.get('session_id') != leftover['owner_session'], \
    'the pid resolves to a live session — only the session ids tell them apart'
print('test_recycled_pid: comparing the pair reports orphan, not live ok')

# --- the explicit recovery is the only road in -------------------------------

recovered = cli('--pid', str(PID), '--session', leftover['owner_session'])
assert [e['owner_session'] for e in recovered['served']] == ['s-old'], recovered
assert outbox.read(repo) == [], 'the recovered event was left in the queue'
print('test_recycled_pid: --session recovers the orphan, once ok')

# --- an owner that died with no successor stamps nothing ---------------------
# The identity is cached at validation, but a press made after the owner is
# gone must not be attributed to it: no record, no stamp, and any chat may
# serve what nobody owns.

(sessions / f'{PID}.json').unlink()
answer = Fake().launch({'road': 'unattended'})
assert answer.get('queued') is True, answer
orphaned = outbox.read(repo)[0]
assert 'owner' not in orphaned, \
    f'a press was attributed to an owner that no longer exists: {orphaned}'
print('test_recycled_pid: a press with the owner gone is unowned ok')

# --- a legacy event, queued before the identity was a pair -------------------
# The queue outlives an upgrade. Such an event carries `owner` and nothing
# else: it is served on the pid alone, which is all it ever promised — the
# skill says that limit out loud rather than running a pair check that would
# die on the missing field.

outbox.truncate(repo)
outbox.append(repo, 'foreman', text='queued before the upgrade', owner=PID)
be('s-new')
legacy = cli('--pid', str(PID))
assert [e['text'] for e in legacy['served']] == ['queued before the upgrade'], legacy
assert legacy['remaining'] == [], legacy
print('test_recycled_pid: a legacy pid-only event is still served ok')

server.Handler.owner_identity = None
outbox.truncate(repo)
shutil.rmtree(tmp, ignore_errors=True)
print('test_recycled_pid ok')
