#!/usr/bin/env python3
"""The pre-commit review's findings, pinned so they cannot come back.

Five things the whole-diff review found after every phase had closed green.
Each is asserted here through the door a caller actually uses:

  - a non-ASCII credential answers "no" instead of raising. `compare_digest`
    refuses a non-ASCII `str` and `http.server` decodes headers as latin-1, so
    one byte >= 0x80 used to raise inside the perimeter check — and on GET that
    check runs outside the handler's `try`, so the connection died with a
    traceback instead of answering 403;
  - the queue is read under the SHARED lock. It is the one accessor that had
    none, and it is what the single-run guard consults: an unlocked read skips
    a torn line silently rather than reporting it;
  - a run request past its age no longer refuses the next press. A queue nobody
    drained — the chat was closed — left the button dead for good, with no way
    back from the page;
  - a fresh one still does refuse: the guard is bounded, not removed;
  - naming the active plan costs no parse, and two drains in one process do not
    rename onto the same aside file.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import os
import pathlib
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402
import outbox  # noqa: E402
import server  # noqa: E402

TOKEN = 'the-real-token'
tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-fixes-'))

# --- a non-ASCII credential answers no, and does not raise -----------------


class Probe(server.Handler):
    def __init__(self, headers):
        self.token = TOKEN
        self.cookie_port = 8787
        self.headers = headers


for label, headers in (
        ('header', {server.TOKEN_HEADER: 'café'}),
        ('cookie', {'Cookie': f'{server.cookie_name(8787)}=café'})):
    try:
        answer = Probe(headers).authenticated()
    except Exception as e:
        raise AssertionError(
            f'a non-ASCII credential in the {label} raised {type(e).__name__} '
            f'instead of being refused: {e}')
    assert answer is False, f'a non-ASCII {label} authenticated: {answer}'
print('test_review_fixes: a non-ASCII credential is refused, not raised ok')

# --- the queue is read under the shared lock ------------------------------

seen = []
real_locked = outbox._locked


def watched(f, exclusive):
    seen.append(exclusive)
    return real_locked(f, exclusive)


repo = tmp / 'locked'
repo.mkdir()
outbox.truncate(repo)
outbox._locked = watched
try:
    outbox.read(repo)
finally:
    outbox._locked = real_locked
assert seen == [False], \
    f'read() did not take the shared lock — locks taken: {seen}'
print('test_review_fixes: the queue is read under the shared lock ok')

# --- an unreachable queue still reads as empty ---------------------------

blocked_tmp = pathlib.Path(tempfile.mkdtemp()) / 'sealed'
blocked_tmp.mkdir()
os.chmod(blocked_tmp, 0o500)
real_tmp = outbox.TMP
outbox.TMP = blocked_tmp / 'phased-workflow'
try:
    assert outbox.read(tmp / 'unreachable') == [], \
        'a queue that cannot be locked did not read as empty'
except OSError as e:
    raise AssertionError(
        f'taking the shared lock turned an unreachable queue into a raise: {e}')
finally:
    outbox.TMP = real_tmp
    os.chmod(blocked_tmp, 0o700)
print('test_review_fixes: an unreachable queue still reads as empty ok')

# --- a stale run request no longer blocks the button ----------------------

repo = tmp / 'stale'
(repo / '.phased' / 'active' / 'toy').mkdir(parents=True)
(repo / '.phased' / 'active' / 'toy' / 'plan.md').write_text(
    '# Context: wf/toy\nMode: autonomous\n\n'
    '## Work Plan\n- [ ] **Phase 1**: one\n  - Done: nothing\n')
outbox.truncate(repo)


class Fake(server.Handler):

    def __init__(self, root):
        self.board = type('B', (), {'repo': str(root)})()


fake = Fake(repo)
first = fake.launch({'road': 'unattended'})
assert first.get('queued') is True, f'the first press was refused: {first}'

blocked = fake.launch({'road': 'unattended'})
assert 'error' in blocked, f'a FRESH pending request did not refuse: {blocked}'
print('test_review_fixes: a fresh request still refuses the next press ok')

# age the pending request past the bound, the way an undrained queue ages
queue = outbox.path(repo)
aged = [dict(e, at=time.time() - server.RUN_REQUEST_TTL - 60)
        for e in outbox.read(repo)]
queue.write_text(''.join(json.dumps(e) + '\n' for e in aged), encoding='utf-8')

after = fake.launch({'road': 'unattended'})
assert after.get('queued') is True, \
    ('a request older than the age bound still refuses the next press: the '
     f'button stays dead for good — {after}')
print('test_review_fixes: a stale request no longer blocks the button ok')

# --- a queue line the server did not write does not crash the guard -------

outbox.truncate(repo)
queue.write_text('{"not": "ours"}\n', encoding='utf-8')
survives = fake.launch({'road': 'unattended'})
assert survives.get('queued') is True, \
    ('a JSON line without a kind crashed the launch guard instead of being '
     f'ignored: {survives}')
print('test_review_fixes: a foreign queue line does not crash the guard ok')

# --- naming the active plan costs no parse -------------------------------

assert core.active_slug(repo) == 'toy', \
    f'active_slug did not name the plan directory: {core.active_slug(repo)}'
assert core.active_slug(tmp / 'nothing-here') is None, \
    'active_slug invented a plan where there is none'
print('test_review_fixes: the active plan is named without a parse ok')

# --- two drains in one process do not share an aside name ----------------

repo = tmp / 'aside'
repo.mkdir()
outbox.truncate(repo)
names = []
real_rename = __import__('os').rename


def capture(src, dst, *a, **k):
    names.append(str(dst))
    return real_rename(src, dst, *a, **k)


os.rename = capture
try:
    for _ in range(2):
        outbox.append(repo, 'foreman', text='x')
        outbox.drain(repo)
finally:
    os.rename = real_rename
assert len(names) == 2 and names[0] != names[1], \
    f'two drains in one process renamed onto the same aside file: {names}'
print('test_review_fixes: each drain gets its own aside file ok')

outbox.truncate(repo)
print('test_review_fixes ok')
