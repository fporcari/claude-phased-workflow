#!/usr/bin/env python3
"""Queued events carry their owner, and a drain can take only its own.

The defect this pins: the re-own of a reused server (6.28.0) reached
`Handler.owner_pid` and nothing else — the queue stayed one file per
repository with anonymous events, so ANY chat running `--drain` consumed a
request pressed for another chat's context. Now the server stamps each event
with the owner of the moment (the LAST chat that opened or reused the
dashboard), and `drain(pid=N)` takes only what belongs to N — plus the
unowned events, which predate any owner or were queued by hand. Another
chat's events are written back; whether that chat still lives is the
caller's judgment, and a bare drain still takes everything.

Four things are asserted:

  - `drain(pid=N)` returns N's events and the unowned ones, in order;
  - another owner's event survives the filtered drain, still readable;
  - a bare `drain()` then takes the leftover, emptying the queue;
  - `Handler.launch` stamps the queued run-workflow with the current owner.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import shutil
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import outbox  # noqa: E402
import server  # noqa: E402

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-owner-'))
repo = tmp / 'repo'
(repo / '.phased' / 'active' / 'own').mkdir(parents=True)
(repo / '.phased' / 'active' / 'own' / 'plan.md').write_text(
    '- [ ] **Phase 1**: a\n')
outbox.truncate(repo)

# --- the filtered drain takes its own and the unowned ------------------------

outbox.append(repo, 'foreman', text='mine', owner=111)
outbox.append(repo, 'foreman', text='theirs', owner=222)
outbox.append(repo, 'foreman', text='nobody-s')

got = outbox.drain(repo, pid=111)
assert [e['text'] for e in got] == ['mine', 'nobody-s'], got
left = outbox.read(repo)
assert [e['text'] for e in left] == ['theirs'], \
    f"another chat's event did not survive the filtered drain: {left}"
print('test_outbox_owner: the filtered drain takes its own and the unowned ok')

rest = outbox.drain(repo)
assert [e['text'] for e in rest] == ['theirs'], rest
assert outbox.read(repo) == [], 'the bare drain did not empty the queue'
print('test_outbox_owner: the bare drain takes the leftover ok')

# --- launch stamps the owner of the moment -----------------------------------


class Fake:
    launch = server.Handler.launch

    def __init__(self, repo_root):
        self.board = type('B', (), {'repo': str(repo_root)})()

    owner_stamp = server.Handler.owner_stamp


server.Handler.owner_pid = 4242
try:
    answer = Fake(repo).launch({'road': 'unattended'})
    assert answer.get('queued') is True, answer
    queued = outbox.read(repo)
    assert queued and queued[0].get('owner') == 4242, \
        f'the queued run does not carry its owner: {queued}'
finally:
    server.Handler.owner_pid = None
print('test_outbox_owner: launch stamps the owner of the moment ok')

outbox.truncate(repo)
shutil.rmtree(tmp, ignore_errors=True)
print('test_outbox_owner ok')
