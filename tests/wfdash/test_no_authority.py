#!/usr/bin/env python3
"""Phase 2 contract: the server proposes, it never acts.

`/run-workflow` is not a wrapper around the launcher — it owns the pre-flight,
the log tee, the Monitor on the EVENT stream, the push policy, the foreman
relay, the plan-defect return leg and the run inspection notes that
`/quality-check` and `/finalize-workflow` read. A `Popen` of the launcher from
this server skips every one of them, and the phase button wrote
`/wf:execute-phase` into the supervision chat, which `refs/board.md` forbids by
name.

So the whole spawn surface goes, and both roads become one queued request the
attached chat services with its full context. Asserted as SHAPE — no process is
started here, which is the point.

Five things are asserted:

  - the spawn surface is gone from the module: no `Popen`, and none of the
    functions that existed only to guard it;
  - the socket writers are gone: `inbox` keeps its readers and loses `send`;
  - `/api/launch` enqueues and returns what it queued, for both roads;
  - the phase road hands back a command as TEXT and delivers nothing;
  - the queue file lives outside the repository, so writing it dirties no tree.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import inbox  # noqa: E402
import outbox  # noqa: E402  (the module this phase adds)
import server  # noqa: E402

SRC = (ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash' / 'server.py').read_text()
INBOX_SRC = (ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash' / 'inbox.py').read_text()

# --- the spawn surface is gone ---------------------------------------------

assert 'Popen' not in SRC, 'the server still spawns a process'
for gone in ('start_run', 'run_pidfile', 'alive', 'read_run_pid',
             'run_state_on_disk', 'launch_unattended', 'launch_in_chat'):
    assert not hasattr(server, gone), \
        f'{gone} survives — it existed only to guard or perform the spawn'
assert not hasattr(server, 'RUNS'), 'RUNS survives with no run to remember'
print('test_no_authority: the spawn surface is gone ok')

# --- the socket writers are gone, the readers stay ------------------------

assert 'import socket' not in INBOX_SRC, \
    'inbox still opens a socket: the write channel belongs to refs/foreman.md'
for gone in ('send', 'deliver', 'deliver_first', 'deliver_to', 'peer_token'):
    assert not hasattr(inbox, gone), f'inbox.{gone} still writes into a session'
for kept in ('mirror', 'transcript_tail', 'repo_sessions', 'owner_target'):
    assert hasattr(inbox, kept), f'inbox.{kept} is a reader and must stay'
print('test_no_authority: the socket writers are gone, the readers stay ok')

# --- both roads enqueue ---------------------------------------------------


class Fake(server.Handler):

    def __init__(self, repo):
        self.board = type('B', (), {'repo': repo})()


def queued(repo):
    return outbox.read(repo)


import tempfile  # noqa: E402

repo = tempfile.mkdtemp(prefix='wfdash-phase2-')
outbox.truncate(repo)

PLAN = {'slug': 'guarded', 'next': 3, 'blocked_by': None}
out = Fake(repo).launch({'road': 'unattended'}, plan=PLAN)
events = queued(repo)
assert len(events) == 1, f'the unattended road queued {len(events)} events'
assert events[0]['kind'] == 'run-workflow', events[0]
assert out.get('queued') is True, f'the road did not report enqueuing: {out}'
print('test_no_authority: the unattended road enqueues ok')

outbox.truncate(repo)
out = Fake(repo).launch({'road': 'chat'}, plan=PLAN)
assert out.get('command') == '/wf:execute-phase', \
    f'the phase road must hand back the command as text: {out}'
assert not queued(repo) or queued(repo)[0]['kind'] != 'execute-phase-delivered', \
    'the phase road delivered instead of handing back text'
print('test_no_authority: the phase road hands back a command ok')

# --- the queue is outside the repository ---------------------------------

path = pathlib.Path(outbox.path(repo))
assert not str(path).startswith(str(pathlib.Path(repo).resolve())), \
    f'the queue file is inside the repository: {path}'
print('test_no_authority: the queue lives outside the repository ok')

print('test_no_authority ok')
