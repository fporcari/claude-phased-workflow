#!/usr/bin/env python3
"""The transport under `${TMPDIR:-/tmp}` is owner-only, whatever the umask.

The defect this pins: on a host with no per-user TMPDIR — Linux, typically —
`/tmp/phased-workflow` and the JSONL in it took whatever the umask left,
usually 0755/0644: world-readable queues that name repositories and carry the
commands a chat will run, next to a `/tmp` shared by every user. Only the
`.lock` sidecar was explicit. Now the directory is 0700 and every file 0600,
set at creation and healed on touch.

Three things are asserted, under an umask of 022 so nothing passes by luck
(the server's registry file is covered by test_registry_probe.py):

  - the transport directory is created 0700;
  - the queue file is created 0600, and the `.lock` sidecar stays 0600;
  - a directory and a queue a laxer version left behind are healed on the
    next append.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import os
import pathlib
import stat
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import outbox  # noqa: E402

os.umask(0o022)

# The default transport is namespaced by uid BEFORE the override below: a
# fixed `/tmp/phased-workflow` means the first user to create the 0700
# directory on a shared host locks every other user out. The suffix must
# match run-workflow.sh's `phased-workflow-$(id -u)` — same directory, both
# languages.
assert outbox.TMP.name == f'phased-workflow-{os.getuid()}', \
    f'the transport is not namespaced by uid: {outbox.TMP.name}'
print('test_queue_private: the transport directory is namespaced by uid ok')

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-private-'))
outbox.TMP = tmp / 'phased-workflow'
repo = tmp / 'repo'
repo.mkdir()


def mode(p):
    return stat.S_IMODE(os.stat(p).st_mode)


# --- created private --------------------------------------------------------

outbox.append(repo, 'foreman', text='hello')
queue = outbox.path(repo)
assert mode(outbox.TMP) == 0o700, f'the transport directory is {oct(mode(outbox.TMP))}'
assert mode(queue) == 0o600, f'the queue file is {oct(mode(queue))}'
lock = queue.with_name(queue.name + '.lock')
assert mode(lock) == 0o600, f'the lock sidecar is {oct(mode(lock))}'
print('test_queue_private: directory 0700, queue and lock 0600 ok')

# --- healed on touch ---------------------------------------------------------

os.chmod(outbox.TMP, 0o755)
os.chmod(queue, 0o644)
outbox.append(repo, 'foreman', text='again')
assert mode(outbox.TMP) == 0o700, 'a lax directory was not healed on append'
assert mode(queue) == 0o600, 'a lax queue file was not healed on append'
print('test_queue_private: lax modes healed on the next append ok')

outbox.truncate(repo)
print('test_queue_private ok')
