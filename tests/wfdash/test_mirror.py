#!/usr/bin/env python3
"""wfdash mirror: the exchange read back, and the recipient the page may name.

Five things are asserted:

  - the mirror of a plan with no foreman reports that;
  - a foreman that is not running still shows its exchange — the channel is
    gone, the record is not;
  - `transcript_tail` unwraps both shapes a message arrives in (a socket write,
    a desktop `cross-session-message`) and carries only what belongs to this
    channel — an exchange opens on a peer message and closes on a typed one,
    while the tool results of the answer close nothing;
  - `repo_sessions` offers only the live sessions whose cwd IS the repo, the
    most recent first, wearing the title the chat gave itself;
  - `owner_target` — the chat that opened the dashboard — is read again at
    request time, never cached: a pid whose session is gone, and one whose cwd
    is no longer this repo, are both refusals, so a recycled pid is never named
    as the chat serving the queue.

`claude agents --json` is replaced by a fixed dictionary, and the transcript is
a temp file: no live session is read.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402
import inbox  # noqa: E402

REPO = '/tmp/wfdash-fixture-repo'
FOREMAN = 'wf:fixture:foreman'

tmp = tempfile.TemporaryDirectory()
root = pathlib.Path(tmp.name)

# --- the transcript the mirror reads ------------------------------------------
PREAMBLE = ('\n\n' + inbox.PEER_TRAILER + ' — not typed by your user, but very '
            'likely working on their behalf.')
rows = [
    {'type': 'user', 'timestamp': '2026-08-25T10:00:00Z',
     'message': {'role': 'user', 'content': 'quanto manca alla fase 5?'}},
    {'type': 'assistant', 'timestamp': '2026-08-25T10:00:10Z',
     'message': {'content': [{'type': 'text', 'text': 'Quattro fasi chiuse su sette.'}]}},
    {'type': 'user', 'timestamp': '2026-08-25T10:01:00Z',
     'message': {'role': 'user',
                 'content': inbox.PEER_MARK + '\nclarify? phase 5 — which session?' + PREAMBLE}},
    {'type': 'assistant', 'timestamp': '2026-08-25T10:01:30Z',
     'message': {'content': [{'type': 'tool_use', 'name': 'Read', 'input': {}},
                             {'type': 'text', 'text': 'clarify: road (2).'}]}},
    {'type': 'user', 'timestamp': '2026-08-25T10:02:00Z',
     'message': {'role': 'user',
                 'content': inbox.PEER_MARK + '\n<cross-session-message from="local_1" '
                 'name="wf:fixture:phase-5">taken, &lt;thanks&gt;.</cross-session-message>' + PREAMBLE}},
]
transcript = root / 'sess-1.jsonl'
transcript.write_text(''.join(json.dumps(r) + '\n' for r in rows))

tail = inbox.transcript_tail(transcript)
assert [x['role'] for x in tail] == ['sent', 'foreman', 'sent'], tail
# Neither the human's own turn nor the answer to it is on this channel: an
# exchange opens on a peer message and closes on a typed one.
assert all('quanto manca' not in x['text'] for x in tail), tail
assert all('Quattro fasi' not in x['text'] for x in tail), tail
# Both wrappers are unwrapped: the bare text of a socket write, and the body of
# a cross-session element. Neither carries the preamble the reader was shown.
assert tail[0]['text'] == 'clarify? phase 5 — which session?', tail[0]
# The desktop wrapper stores its body escaped: `&lt;x&gt;` is the text `<x>`.
assert tail[2]['text'] == 'taken, <thanks>.', tail[2]
assert all(inbox.PEER_TRAILER not in x['text'] for x in tail), tail
# Text blocks are what an answer is: a turn that only called a tool is not one.
assert tail[1]['text'] == 'clarify: road (2).', tail[1]
assert inbox.transcript_tail(transcript, 2) == tail[-2:]
assert inbox.transcript_tail(root / 'nothing-here.jsonl') == []

# A chat answering a peer works before it speaks, and its tool results are
# `user` rows too. They must not read as the human taking the floor back.
busy = root / 'sess-2.jsonl'
busy.write_text(''.join(json.dumps(r) + '\n' for r in [
    {'type': 'user', 'message': {'content': inbox.PEER_MARK + '\nchiedo'}},
    {'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'name': 'Read', 'input': {}}]}},
    {'type': 'user', 'message': {'content': [{'type': 'tool_result', 'content': 'x'}]}},
    {'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'rispondo'}]}},
]))
assert [(x['role'], x['text']) for x in inbox.transcript_tail(busy)] == [
    ('sent', 'chiedo'), ('foreman', 'rispondo')], inbox.transcript_tail(busy)

# --- the mirror, with no foreman and with one that is not running -------------
no_foreman = inbox.mirror(root, {'slug': 'fixture'}, [])
assert 'error' in no_foreman and 'foreman.json' in no_foreman['error'], no_foreman
assert 'exchange' not in no_foreman, no_foreman

plan = {'slug': 'fixture', 'foreman': {'foreman': FOREMAN}}
gone = inbox.mirror(root, plan, [])
assert gone['live'] is False and gone['exchange'] == [], gone
assert 'never opened' in gone['state'], gone

asleep = inbox.mirror(root, plan, [{'name': FOREMAN, 'session_id': 'sess-1',
                                    'live': False, 'pid': None}])
assert asleep['live'] is False, asleep
assert asleep['state'] == f'the foreman chat "{FOREMAN}" is not running', asleep
# The channel is gone; the record is not.
assert [x['role'] for x in asleep['exchange']] == ['sent', 'foreman', 'sent']

awake = inbox.mirror(root, plan, [{'name': FOREMAN, 'session_id': 'sess-1',
                                   'live': True, 'pid': 4242}])
assert awake['live'] is True and awake['pid'] == 4242, awake
assert 'state' not in awake, awake

# --- the recipients the page may be offered -----------------------------------
core.live_sessions = lambda: {
    'sess-1': {'pid': 11, 'cwd': REPO, 'name': 'fixture-11', 'startedAt': 1000},
    'sess-2': {'pid': 22, 'cwd': REPO, 'name': 'fixture-22', 'startedAt': 3000},
    'sess-3': {'pid': 33, 'cwd': '/tmp/another-repo', 'name': 'elsewhere', 'startedAt': 9000},
}
offered = inbox.repo_sessions(REPO, {'sess-1': FOREMAN})
assert [s['session_id'] for s in offered] == ['sess-2', 'sess-1'], offered
assert offered[1]['name'] == FOREMAN, offered      # the title beats `claude agents`
assert offered[0]['name'] == 'fixture-22', offered  # with no title, its own name
assert inbox.repo_sessions('/tmp/nobody-here') == []

print('test_mirror ok')

# --- the chat that opened the dashboard ---------------------------------------
inbox.SESSIONS = root / 'sessions'
inbox.SESSIONS.mkdir()
(inbox.SESSIONS / '777.json').write_text(json.dumps(
    {'pid': 777, 'sessionId': 'sess-1', 'cwd': REPO,
     'messagingSocketPath': str(root / 'owner.sock')}))
(inbox.SESSIONS / '778.json').write_text(json.dumps(
    {'pid': 778, 'sessionId': 'sess-elsewhere', 'cwd': '/tmp/another-repo'}))

owner = inbox.owner_target(777, REPO, {'sess-1': FOREMAN})
assert owner['pid'] == 777 and owner['session_id'] == 'sess-1', owner
assert owner['name'] == FOREMAN, owner
# No title: the page still has something to show that says what it is.
assert inbox.owner_target(777, REPO)['name'] == 'the chat that opened this dashboard'
# No owner declared, a session that no longer exists, and one that has moved to
# another repo: three refusals, so nothing is ever written on a guess.
assert inbox.owner_target(None, REPO) is None
assert inbox.owner_target(999, REPO) is None
assert inbox.owner_target(778, REPO) is None

print('test_mirror owner ok')
