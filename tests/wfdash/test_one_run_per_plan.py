#!/usr/bin/env python3
"""Phase 3 contract: one unattended run per plan.

The graft deleted the `one unattended run per plan` guard — a pidfile plus a
`ps` check — and never re-established it. Reproduced: two presses of *Ask for
an unattended run* queue two identical `run-workflow` requests, so the chat
draining the queue reads two orders to run on one working tree. That is exactly
the invariant the removed guard protected, and the queue is now the only place
it can be enforced from.

The server proposes and the chat acts, so nothing here starts a process: what is
asserted is which REQUESTS the two roads leave behind.

Four things are asserted:

  - the first press queues one `run-workflow` request;
  - the second press is REFUSED while the first is still pending, and queues
    nothing;
  - once the queue is drained, a press is accepted again;
  - the chat road is never refused by this guard: it queues nothing, so it
    cannot collide with anything.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import outbox  # noqa: E402
import server  # noqa: E402

PLAN = """# Context: wf/toy
Parent: main
Mode: autonomous

## Objective
A plan with one eligible phase.

## Work Plan
- [ ] **Phase 1**: the only phase
  - Done: nothing
"""

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-onerun-'))


class Fake:
    """The handler's launch method, with the one attribute it reads."""

    launch = server.Handler.launch

    def __init__(self, repo_root):
        self.board = type('B', (), {'repo': str(repo_root)})()
        self.owner_pid = None


root = tmp / 'toy'
(root / '.phased' / 'active' / 'toy').mkdir(parents=True)
(root / '.phased' / 'active' / 'toy' / 'plan.md').write_text(PLAN)
outbox.truncate(root)
fake = Fake(root)

# --- the first press queues one request -----------------------------------

first = fake.launch({'road': 'unattended'})
assert first.get('queued') is True, f'the first press was not queued: {first}'
queued = [e for e in outbox.read(root) if e['kind'] == 'run-workflow']
assert len(queued) == 1, f'the first press queued {len(queued)} requests'
print('test_one_run_per_plan: the first press queues one request ok')

# --- the second press is refused while the first is pending ---------------

second = fake.launch({'road': 'unattended'})
assert 'error' in second, \
    ('the second press was accepted: two orders to run unattended on one '
     f'working tree — {second}')
assert 'queued' not in second, f'the refusal queued something anyway: {second}'
queued = [e for e in outbox.read(root) if e['kind'] == 'run-workflow']
assert len(queued) == 1, \
    f'the refused press left {len(queued)} requests in the queue'
print('test_one_run_per_plan: a second press is refused while one is pending ok')

# --- the chat road is untouched by the guard ------------------------------

chat = fake.launch({'road': 'chat'})
assert chat.get('road') == 'chat' and 'command' in chat, \
    f'the chat road was refused by the unattended guard: {chat}'
assert 'error' not in chat, f'the chat road answered an error: {chat}'
assert [e for e in outbox.read(root) if e['kind'] == 'run-workflow'], \
    'the chat road drained or replaced the pending request'
print('test_one_run_per_plan: the chat road is not gated by the guard ok')

# --- drained, a press is accepted again ----------------------------------

outbox.truncate(root)
again = fake.launch({'road': 'unattended'})
assert again.get('queued') is True, \
    f'a press after the queue was drained was still refused: {again}'
print('test_one_run_per_plan: a drained queue lets the next press through ok')

outbox.truncate(root)
print('test_one_run_per_plan ok')
