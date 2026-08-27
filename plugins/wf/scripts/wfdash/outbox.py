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
`${TMPDIR:-/tmp}/phased-workflow/` — the same transport `run-workflow.sh`
already uses for its stop request and its consult answer, chosen there for the
same reason: nothing the dashboard does may dirty the tree it watches.

One file per repository, appended by the server and drained by the chat:

    python3 outbox.py -C <repo>            what is pending, as JSON
    python3 outbox.py -C <repo> --drain    the same, and the queue is emptied
"""

import argparse
import hashlib
import json
import os
import pathlib
import threading
import time

TMP = pathlib.Path(os.environ.get('TMPDIR') or '/tmp') / 'phased-workflow'
_LOCK = threading.Lock()


def path(repo):
    """The queue file of one repository. Never inside it."""
    root = os.path.realpath(os.path.expanduser(repo))
    return TMP / f'{pathlib.Path(root).name}-{hashlib.sha1(root.encode()).hexdigest()[:12]}-outbox.jsonl'


def append(repo, kind, **fields):
    """Queue one request and return it, exactly as it was written."""
    event = dict(fields, kind=kind, at=time.time())
    f = path(repo)
    with _LOCK:
        f.parent.mkdir(parents=True, exist_ok=True)
        with open(f, 'a', encoding='utf-8') as fh:
            fh.write(json.dumps(event, ensure_ascii=False) + '\n')
    return event


def read(repo):
    """The pending requests, oldest first. A line that is not JSON is skipped."""
    try:
        raw = path(repo).read_text(encoding='utf-8', errors='replace')
    except OSError:
        return []
    out = []
    for line in raw.splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def truncate(repo):
    """Drop what was served. A queue nobody drained is not a queue."""
    with _LOCK:
        try:
            os.remove(path(repo))
        except OSError:
            pass


def main():
    ap = argparse.ArgumentParser(description='The dashboard requests waiting for this chat.')
    ap.add_argument('-C', '--cwd', default=os.getcwd(), help='the repo whose queue to read')
    ap.add_argument('--drain', action='store_true', help='empty the queue after reading it')
    args = ap.parse_args()
    events = read(args.cwd)
    if args.drain:
        truncate(args.cwd)
    print(json.dumps(events, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
