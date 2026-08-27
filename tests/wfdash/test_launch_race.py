#!/usr/bin/env python3
"""The `one unattended run per plan` guard holds under concurrent presses.

The defect this pins, reproduced before the fix: `launch` read the queue under
a SHARED lock and appended under a separate exclusive one, so two requests
landing together both found the queue empty, both passed the guard, and the
server answered `queued` twice — two orders to run unattended on one working
tree, the very invariant the guard exists for. The consumer's same-kind
collapse limited the damage, but the queue held two events and the page was
told twice that its press was the first.

The fix is `outbox.append_if_absent`: check and append as ONE step under ONE
exclusive lock. Exercised at the edge: every press is released by a barrier at
the same instant.

Three things are asserted:

  - of N simultaneous presses exactly ONE is accepted, the rest are refused;
  - the queue holds exactly ONE `run-workflow` event afterwards;
  - `append_if_absent` returns the event it wrote, and None on the refusals —
    the caller can tell what happened without a second read.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import shutil
import sys
import tempfile
import threading
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import outbox  # noqa: E402
import server  # noqa: E402

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-race-'))
root = tmp / 'repo'
(root / '.phased' / 'active' / 'race').mkdir(parents=True)
(root / '.phased' / 'active' / 'race' / 'plan.md').write_text(
    '- [x] **Phase 1**: a\n- [ ] **Phase 2**: b\n')
outbox.truncate(root)


class Fake:
    launch = server.Handler.launch
    owner_stamp = server.Handler.owner_stamp

    def __init__(self, repo_root):
        self.board = type('B', (), {'repo': str(repo_root)})()
        self.owner_pid = None


# --- N presses released together: one accepted -----------------------------

N = 8
fake = Fake(root)
barrier = threading.Barrier(N)
answers = [None] * N


def press(i):
    barrier.wait()
    answers[i] = fake.launch({'road': 'unattended'})


threads = [threading.Thread(target=press, args=(i,)) for i in range(N)]
for t in threads:
    t.start()
for t in threads:
    t.join(timeout=30)
    assert not t.is_alive(), 'a press never returned — a deadlock in the guard'

accepted = [a for a in answers if a and a.get('queued')]
refused = [a for a in answers if a and 'error' in a]
assert len(accepted) == 1, f'{len(accepted)} presses were accepted: {answers}'
assert len(refused) == N - 1, f'{len(refused)} presses were refused: {answers}'
print('test_launch_race: one press accepted, the rest refused ok')

queued = [e for e in outbox.read(root) if e.get('kind') == 'run-workflow']
assert len(queued) == 1, f'the queue holds {len(queued)} run-workflow events: {queued}'
print('test_launch_race: the queue holds exactly one event ok')

# --- append_if_absent answers for itself ------------------------------------

outbox.truncate(root)
fresh = time.time() - 60
first = outbox.append_if_absent(root, 'run-workflow', fresh, command='/wf:run-workflow')
assert first is not None and first['kind'] == 'run-workflow', first
second = outbox.append_if_absent(root, 'run-workflow', fresh, command='/wf:run-workflow')
assert second is None, f'the second append was not refused: {second}'
# A pending event OLDER than the freshness bound does not refuse: the stale
# queue must not leave the button dead for good.
stale = outbox.append_if_absent(root, 'run-workflow', time.time() + 1,
                                command='/wf:run-workflow')
assert stale is not None, 'a stale pending event left the button dead'
print('test_launch_race: append_if_absent returns the event or None ok')

outbox.truncate(root)
shutil.rmtree(tmp, ignore_errors=True)
print('test_launch_race ok')
