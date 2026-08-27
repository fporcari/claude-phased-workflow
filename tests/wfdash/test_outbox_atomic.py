#!/usr/bin/env python3
"""Phase 1 contract: the request queue survives two processes.

The defect this pins, reproduced before the plan was written: `--drain` read the
file and then removed it as two unsynchronised steps, so a button press landing
between them was destroyed silently. `_LOCK` was a `threading.Lock` and the
drain runs in a different process from the server, so it guarded nothing across
that boundary — protection in name, none in fact.

The window is exercised at its exact edge: the press is started from inside the
rename, so it can only land after the queue has been moved aside. It goes to a
fresh queue file and must still be there when the drain returns. Under the old
read-then-remove pair it was deleted.

Four things are asserted:

  - a plain drain returns everything queued and empties the queue;
  - a press landing INSIDE the drain window survives it;
  - the lock is a file other processes can see: a `.lock` sidecar next to the
    queue, not a lock object inside one interpreter;
  - the queue still lives outside every repository.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import os
import pathlib
import sys
import tempfile
import threading

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import outbox  # noqa: E402

repo = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-outbox-'))
outbox.truncate(repo)

# --- a plain drain empties what it returns ---------------------------------

outbox.append(repo, 'run-workflow', command='/wf:run-workflow', phase=1)
outbox.append(repo, 'foreman', text='hello')
got = outbox.drain(repo)
assert [e['kind'] for e in got] == ['run-workflow', 'foreman'], \
    f'drain lost or reordered what was queued: {got}'
assert outbox.read(repo) == [], 'the queue was not emptied by the drain'
print('test_outbox_atomic: a drain returns everything and empties the queue ok')

# --- a press inside the drain window survives ------------------------------

outbox.append(repo, 'run-workflow', command='/wf:run-workflow', phase=2)

pressed = []
real_rename = os.rename


def rename_then_press(src, dst, *a, **k):
    """Move the queue aside, then press — from another thread, so the press
    waits on the lock the drain still holds instead of deadlocking on it."""
    real_rename(src, dst, *a, **k)
    t = threading.Thread(target=lambda: outbox.append(repo, 'foreman',
                                                      text='landed mid-drain'))
    t.start()
    pressed.append(t)


os.rename = rename_then_press
try:
    drained = outbox.drain(repo)
finally:
    os.rename = real_rename
for t in pressed:
    t.join(timeout=10)
    assert not t.is_alive(), 'the mid-drain press never completed — a deadlock'

assert pressed, 'the drain never renamed the queue aside — the window is not there'
assert [e['kind'] for e in drained] == ['run-workflow'], \
    f'the drain returned the wrong batch: {drained}'
left = outbox.read(repo)
assert [e['kind'] for e in left] == ['foreman'], \
    f'the press that landed inside the drain window was destroyed: {left}'
print('test_outbox_atomic: a press inside the drain window survives ok')

# --- the lock is visible to other processes --------------------------------

queue = outbox.path(repo)
sidecars = list(queue.parent.glob(queue.name + '.lock'))
assert sidecars, \
    'no .lock sidecar beside the queue: the lock cannot be seen by another process'
print('test_outbox_atomic: the lock is a file, not an object in one interpreter ok')

# --- the queue is outside the repository ----------------------------------

assert not str(queue).startswith(str(repo)), \
    f'the queue is inside the repository it serves: {queue}'
print('test_outbox_atomic: the queue lives outside the repository ok')

outbox.truncate(repo)
print('test_outbox_atomic ok')
