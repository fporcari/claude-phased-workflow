#!/usr/bin/env python3
"""wfdash under concurrent handlers: what the threaded server may not corrupt.

`serve()` returns a ThreadingHTTPServer and several endpoints re-enter the same
objects, so two requests can be inside the same reader or the same writer at
once. Both cases used to be unguarded, and both are silent: the numbers are
simply wrong afterwards, and nothing on the page says so.

Three things are asserted:

  - two threads updating one transcript at the same time count every row ONCE.
    Without the lock both read from the same offset before either advances it,
    so every row is counted twice and the offset ends past the end of the file.
    The fixture is deliberately a few MB: the window is the file read, which
    releases the GIL, and a small file closes it too fast to catch anything.
    Mutation-checked at this size — remove the lock and this fails every run,
    at 2x the rows and 2x the offset;
  - a full re-read (the file shrank) keeps the lock object it is holding: the
    reset must not replace it;
  - the live-session list is fetched ONCE per window however many callers ask
    for it, concurrently or not. It costs a process launch — measured at four
    fifths of a warm response — and four endpoints ask independently while the
    page polls every 5s.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import pathlib
import sys
import tempfile
import threading

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-conc-'))


def row(i):
    return json.dumps({'type': 'assistant', 'timestamp': f'2026-08-26T10:00:{i % 60:02d}.000Z',
                       'cwd': '/somewhere',
                       'message': {'model': 'claude-opus-5',
                                   'usage': {'output_tokens': 10, 'cache_read_input_tokens': 100},
                                   'content': [{'type': 'text', 'text': 'x' * 200}]}})


# --- the reader counts every row once, under two threads --------------------

# ~2 MB: enough that the read holds the window open. Costs a fifth of a second.
ROWS = 5000
t = tmp / 'chat.jsonl'
t.write_text('\n'.join(row(i) for i in range(ROWS)) + '\n')

scan = core.Scan(t)
start = threading.Barrier(2)


def hammer():
    start.wait()
    scan.update()


threads = [threading.Thread(target=hammer) for _ in range(2)]
for th in threads:
    th.start()
for th in threads:
    th.join()

assert scan.turns == ROWS, \
    f'rows counted {scan.turns}, expected {ROWS} — two threads read the same bytes'
assert scan.output == ROWS * 10, f'output {scan.output}, expected {ROWS * 10}'
assert scan.offset == t.stat().st_size, f'offset {scan.offset} vs size {t.stat().st_size}'
print('test_concurrency: the reader counts every row once ok')

# --- a full re-read keeps its lock ------------------------------------------

held = scan.lock
t.write_text(row(0) + '\n')            # shrank: forces the reset path
scan.update()
assert scan.lock is held, 'the reset replaced the lock it was holding'
assert scan.turns == 1, f'after the rewrite: {scan.turns}'
print('test_concurrency: a full re-read keeps its lock ok')

# --- the session list is fetched once per window ---------------------------

calls = []


def counted():
    calls.append(1)
    return {'s1': {'sessionId': 's1'}}


core._read_sessions = counted
core._sessions_cache.update(at=0.0, value={})

ready = threading.Barrier(6)


def ask():
    ready.wait()
    assert core.live_sessions() == {'s1': {'sessionId': 's1'}}


askers = [threading.Thread(target=ask) for _ in range(6)]
for th in askers:
    th.start()
for th in askers:
    th.join()
for _ in range(20):
    core.live_sessions()

assert len(calls) == 1, f'the session list was fetched {len(calls)} times, expected 1'

# past the window it is fetched again: the list changes when a session opens
core._sessions_cache['at'] -= core.SESSIONS_TTL_S + 1
core.live_sessions()
assert len(calls) == 2, f'the cache never expires: {len(calls)} fetches'
print('test_concurrency: the session list is fetched once per window ok')

print('test_concurrency ok')
