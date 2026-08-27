#!/usr/bin/env python3
"""What the dashboard asks for, and the chat carries out.

The server proposes; it never acts. A run belongs to `/wf:run-workflow`, which
owns the pre-flight, the log tee, the Monitor on the EVENT stream, the push
policy, the foreman relay and the plan-defect return leg; the foreman channel
belongs to `refs/foreman.md`. A process that spawned the launcher or wrote a
session socket itself would skip every one of them, so a button here becomes a
REQUEST, and the chat that opened the dashboard serves it with its full
context.

The request rides a JSONL file outside every working tree, under
`${TMPDIR:-/tmp}/phased-workflow-<uid>/` — the same transport
`run-workflow.sh` already uses for its stop request and its consult answer,
chosen there for the same reason: nothing the dashboard does may dirty the
tree it watches. The uid suffix is what makes the `/tmp` fallback multi-user:
without it, the first user to create the 0700 directory on a shared host
locks every other user out of the transport.

One file per repository, appended by the server and drained by the chat:

    python3 outbox.py -C <repo>            what is pending, as JSON
    python3 outbox.py -C <repo> --drain    the same, and the queue is emptied
"""

import argparse
import contextlib
import fcntl
import hashlib
import itertools
import json
import os
import pathlib
import threading
import time

import inbox

# The uid suffix mirrors run-workflow.sh's `phased-workflow-$(id -u)`: the
# two computations must name the same directory, in both languages.
TMP = (pathlib.Path(os.environ.get('TMPDIR') or '/tmp')
       / f'phased-workflow-{os.getuid()}')
# The aside file a drain renames onto must be unique per drain, not per process:
# two threads sharing a pid would rename onto the same name and one would lose
# its batch.
_SERIAL = itertools.count()
_locks = {}
_locks_guard = threading.Lock()


def private_dir(d):
    """The transport directory, owner-only. `/tmp` is shared on a multi-user
    host and the queue names repositories and carries commands, so the
    directory is 0700 and every file in it 0600 — explicitly, not whatever the
    umask leaves. The chmod also heals a directory a laxer version created;
    one owned by somebody else cannot be healed, and degrading beats a 500."""
    d.mkdir(mode=0o700, parents=True, exist_ok=True)
    with contextlib.suppress(OSError):
        os.chmod(d, 0o700)


def _thread_lock(f):
    with _locks_guard:
        return _locks.setdefault(str(f), threading.RLock())


@contextlib.contextmanager
def _locked(f, exclusive):
    """The queue held against both threads and other processes.

    The `flock` is taken on a `.lock` sidecar, never on the queue itself: the
    drain renames the queue aside, which would orphan the descriptor the next
    writer is waiting on.
    """
    private_dir(f.parent)
    with _thread_lock(f):
        fd = os.open(f.with_name(f.name + '.lock'), os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)


def key(repo):
    """One repository, one name — shared by the queue and the server registry."""
    root = os.path.realpath(os.path.expanduser(repo))
    return f'{pathlib.Path(root).name}-{hashlib.sha1(root.encode()).hexdigest()[:12]}'


def path(repo):
    """The queue file of one repository. Never inside it."""
    return TMP / f'{key(repo)}-outbox.jsonl'


def append(repo, kind, **fields):
    """Queue one request and return it, exactly as it was written."""
    event = dict(fields, kind=kind, at=time.time())
    f = path(repo)
    with _locked(f, exclusive=True):
        _append_line(f, event)
    return event


def append_if_absent(repo, kind, fresh_after, **fields):
    """Queue one request, unless a same-kind one newer than `fresh_after` is
    already pending — and return None instead.

    Check and write under ONE exclusive lock: a guard that reads under its own
    lock and appends under another lets two concurrent presses both find the
    queue empty and both queue, which is the invariant this exists to hold.
    """
    f = path(repo)
    with _locked(f, exclusive=True):
        if any(e.get('kind') == kind and e.get('at', 0) > fresh_after
               for e in _entries(f)):
            return None
        event = dict(fields, kind=kind, at=time.time())
        _append_line(f, event)
    return event


def _append_line(f, event):
    fd = os.open(f, os.O_CREAT | os.O_WRONLY | os.O_APPEND, 0o600)
    with contextlib.suppress(OSError):          # heals a file a laxer version left
        os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'a', encoding='utf-8') as fh:
        fh.write(json.dumps(event, ensure_ascii=False) + '\n')


def _entries(f):
    try:
        raw = f.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return []
    out = []
    for line in raw.splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def read(repo):
    """The pending requests, oldest first. A line that is not JSON is skipped.

    Under the SHARED lock: a torn line is skipped rather than raised, so an
    unlocked read drops a request instead of reporting it, and the launch
    guard reads this.
    """
    f = path(repo)
    try:
        with _locked(f, exclusive=False):
            return _entries(f)
    except OSError:
        # A queue that cannot even be locked reads as empty, the way an absent
        # one always did: taking the lock must not turn a degradation into a
        # 500 on the page.
        return _entries(f)


def drain(repo, pid=None, session=None):
    """The pending requests this drain takes, and the queue emptied of them."""
    return drain_split(repo, pid, session)['served']


def _is_mine(event, pid, session):
    """Whether this drain may take one event.

    A pid alone does not identify a chat: the system recycles pids, and a new
    Claude session on the same repository would pass the owner check the dead
    one's request was stamped with — cwd cannot tell the two apart. So an
    event stamped with a session id is served only to a caller carrying THAT
    session id. A caller that cannot name its own session (no record: a test,
    a hand-run drain) keeps the old pid-only guarantee rather than being
    stranded — identify yourself and the pair is enforced.
    """
    owner = event.get('owner')
    if owner is None:
        return True
    if owner != pid:
        return False
    stamped = event.get('owner_session')
    return not (stamped and session and stamped != session)


def drain_split(repo, pid=None, session=None):
    """Both halves of one drain: `served` and `remaining`, from ONE lock.

    The queue is renamed aside and read UNDER the lock, and what this drain
    does not take is written back to a fresh queue before the lock is
    released: a press landing mid-drain appends to that fresh file and
    survives, while another chat's events cannot be lost between the read and
    the write-back. (Reading outside the lock was safe only while a drain took
    everything.) Reading and then removing, the pair this replaced, destroyed
    the press outright.

    With `pid`, the drain takes only what belongs to this chat: the events
    this chat owns (`_is_mine` — the pid, and the session id where the event
    carries one) and the unstamped ones (queued before any owner was known, or
    by hand). Another chat's events are written back — whether that chat still
    lives is a judgment for the caller, not this transport, and a bare drain
    still takes everything.

    `remaining` is what THIS drain left behind, not a later reading of the
    queue: a drain followed by its own `read()` takes two locks, and anything
    appended between them lands in the second answer as though the drain had
    declined it. One lock, one partition, and the two halves cannot disagree.
    """
    f = path(repo)
    aside = f.with_name(f'{f.name}.draining-{os.getpid()}-{next(_SERIAL)}')
    with _locked(f, exclusive=True):
        try:
            os.rename(f, aside)
        except OSError:
            return {'served': [], 'remaining': []}
        events = _entries(aside)
        kept = ([] if pid is None else
                [e for e in events if not _is_mine(e, pid, session)])
        for e in kept:
            _append_line(f, e)
    with contextlib.suppress(OSError):
        os.remove(aside)
    return {'served': [e for e in events if e not in kept], 'remaining': kept}


def truncate(repo):
    """Drop what was served. A queue nobody drained is not a queue."""
    f = path(repo)
    with _locked(f, exclusive=True):
        with contextlib.suppress(OSError):
            os.remove(f)


def main():
    ap = argparse.ArgumentParser(description='The dashboard requests waiting for this chat.')
    ap.add_argument('-C', '--cwd', default=os.getcwd(), help='the repo whose queue to read')
    ap.add_argument('--drain', action='store_true', help='empty the queue after reading it')
    ap.add_argument('--pid', type=int, default=None,
                    help='with --drain: take only the events owned by this '
                         'chat (its pid AND its session id) or owned by '
                         "nobody; another chat's events stay queued")
    ap.add_argument('--session', default=None, metavar='ID',
                    help='with --drain --pid: take the events stamped with '
                         'THIS session id instead of the one the pid resolves '
                         'to now — how an orphan is recovered after its pid '
                         'was recycled (both values are printed in the '
                         "previous drain's `remaining`)")
    args = ap.parse_args()
    if args.drain and args.pid:
        # A filtered drain answers with BOTH halves: what it served, and what
        # it left for another owner — partitioned inside the drain's own lock,
        # never by a second read, which would answer about a queue that moved
        # in between.
        # The session id behind the pid, from the ONE owner check the server
        # uses: a recycled pid must not inherit the dead chat's requests.
        # `--session` overrides that resolution, and is the ONLY way to
        # recover an orphan whose pid a living chat now holds: resolution
        # would answer with the living session and rightly refuse the dead
        # one's event, leaving it queued for ever.
        session = args.session or (inbox.owner_target(args.pid, args.cwd)
                                   or {}).get('session_id')
        out = drain_split(args.cwd, pid=args.pid, session=session)
    else:
        out = drain(args.cwd) if args.drain else read(args.cwd)
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
