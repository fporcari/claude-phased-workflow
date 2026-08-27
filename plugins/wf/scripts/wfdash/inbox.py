"""What the dashboard READS out of a live session, and nothing else.

A session publishes two files this module reads:

    ~/.claude/sessions/<pid>.json           cwd, sessionId, the pid behind them
    <project dir>/<sessionId>.jsonl         the transcript, its own record

Writing lived here until the server lost its authority over the work: a turn
injected into a session skips the skill that owns it, so the foreman channel
went back to `refs/foreman.md` and the dashboard's buttons became requests on
`outbox.py`. What is left is the reading half — who the foreman is, whether it
is running, and what was said to it — and the mirror that shows the exchange.

The exchange is read where it actually lands: the recipient's transcript, the
same file the panels already read, never a second channel.

Nothing here writes to disk.
"""
import html
import json
import os
import pathlib
import re

import core

HOME = pathlib.Path.home()
SESSIONS = HOME / '.claude' / 'sessions'


# How the recipient wraps a message another session sent it. The mirror shows
# what was sent, not the wrapper the reader is shown.
PEER_MARK = 'Another Claude session sent a message:'
PEER_TRAILER = 'This came from another Claude session'
XSESSION_RE = re.compile(r'<cross-session-message[^>]*>(.*?)</cross-session-message>', re.S)
# Transcripts reach a few MB and only the end of one is an exchange: the tail
# is read, never the file.
TAIL_BYTES = 512 * 1024
MIRROR_TURNS = 20


def session_record(pid):
    """`~/.claude/sessions/<pid>.json`, or None when the session is gone."""
    f = SESSIONS / f'{pid}.json'
    if not f.is_file():
        return None
    try:
        return json.loads(f.read_text())
    except (ValueError, OSError):
        return None


def foreman_chat(plan, chats):
    """The foreman's title, and the chat wearing it — running or not.

    Writing needs a running chat; reading its transcript does not, so the two
    answers are separated here instead of at each caller.
    """
    title = ((plan or {}).get('foreman') or {}).get('foreman')
    for c in chats:
        if c.get('name') == title:
            return title, c
    return title, None


def foreman_target(plan, chats):
    """The pid behind the title in `foreman.json`.

    The title is the foreman's address (the plugin's own protocol), and the
    chats already carry it: `core.Board.agents` reads the title from the
    transcript and the pid from the live sessions. Nothing new is scanned.
    """
    title, chat = foreman_chat(plan, chats)
    if not title:
        return {'error': 'this plan has no foreman.json, so there is nobody to write to'}
    if chat is None:
        return {'error': f'no chat is titled "{title}" — the foreman never opened, or it is gone'}
    if not chat.get('live') or not chat.get('pid'):
        return {'error': f'the foreman chat "{title}" is not running'}
    return {'title': title, 'pid': chat['pid'], 'session_id': chat.get('session_id')}


def repo_sessions(repo, titles=None):
    """The live sessions whose cwd IS this repo — the only recipients the page may offer.

    A repo with no plan has no `foreman.json` and therefore no address of its
    own, so the recipient of the first command cannot be resolved the way the
    foreman is. It is still not taken from the request: the server publishes
    THIS list, and the page can only name something that is in it.
    """
    here = os.path.realpath(os.path.expanduser(repo))
    out = []
    for sid, rec in core.live_sessions().items():
        cwd = rec.get('cwd')
        if not cwd or os.path.realpath(cwd) != here:
            continue
        out.append({'session_id': sid, 'pid': rec.get('pid'),
                    'name': (titles or {}).get(sid) or rec.get('name') or sid[:8],
                    'started': rec.get('startedAt')})
    out.sort(key=lambda s: -(s.get('started') or 0))
    return out


def owner_target(pid, repo, titles=None):
    """The chat that started this server, re-read at write time.

    `/wf:dashboard` declares it on the command line — the session that ran the
    skill — and re-declares it through `/api/owner` when a later chat reuses
    the server, so the recipient of the first command is not named by the page
    and not guessed: it is the chat the person is talking to NOW.

    Nothing about it is cached. The server outlives chats, and a pid the system
    has recycled would otherwise receive a stranger's command, so the record is
    read again here and the cwd checked against this repo every time.
    """
    if not pid:
        return None
    record = session_record(pid)
    if record is None:
        return None
    cwd = record.get('cwd')
    if not cwd or os.path.realpath(cwd) != os.path.realpath(os.path.expanduser(repo)):
        return None
    sid = record.get('sessionId')
    return {'session_id': sid, 'pid': pid,
            'name': (titles or {}).get(sid) or 'the chat that opened this dashboard'}


def _peer_text(content):
    """What was sent, out of the wrapper the recipient is shown.

    Two wrappers reach a transcript: a socket write arrives as the bare text
    after the mark, a desktop `send_message` inside a `cross-session-message`
    element — whose body is stored HTML-escaped, so a command carrying
    `<name>` reads `&lt;name&gt;` unless it is decoded here. Both are
    unwrapped; anything else is left as it stands.
    """
    body = content.split(PEER_MARK, 1)[1]
    cut = body.find(PEER_TRAILER)
    if cut > 0:
        body = body[:cut]
    m = XSESSION_RE.search(body)
    if m:
        body = html.unescape(m.group(1))
    return body.strip()


def transcript_tail(path, limit=MIRROR_TURNS):
    """The end of one exchange: the messages written into a chat, and its answers.

    Only those two, and an answer is one only while it is still answering: a
    peer message opens the exchange, a turn the human typed closes it. What
    that chat says to its own user is their conversation — showing it without
    the questions would be a wall of half a dialogue.
    """
    path = pathlib.Path(path)
    try:
        size = path.stat().st_size
        with open(path, 'rb') as fh:
            if size > TAIL_BYTES:
                fh.seek(size - TAIL_BYTES)
                fh.readline()          # the first line is half a row
            raw = fh.read()
    except OSError:
        return []
    out = []
    answering = False
    for line in raw.decode('utf-8', 'replace').splitlines():
        try:
            d = json.loads(line)
        except ValueError:
            continue
        kind = d.get('type')
        msg = d.get('message') or {}
        content = msg.get('content')
        if kind == 'user' and isinstance(content, str) and PEER_MARK in content:
            text = _peer_text(content)
            if text:
                answering = True
                out.append({'role': 'sent', 'text': text, 'ts': d.get('timestamp')})
        elif kind == 'user' and isinstance(content, str) and not d.get('isMeta'):
            # A typed turn, so the chat has moved on. A `user` row carrying a
            # list is the agent's own tool results, and answers nothing.
            answering = False
        elif answering and kind == 'assistant' and isinstance(content, list):
            text = ' '.join(b.get('text') or '' for b in content
                            if isinstance(b, dict) and b.get('type') == 'text').strip()
            if text:
                out.append({'role': 'foreman', 'text': text, 'ts': d.get('timestamp')})
    return out[-limit:]


def mirror(project_dir, plan, chats, limit=MIRROR_TURNS):
    """The foreman's side of the channel: whether it can be written to, and the exchange.

    The state and the exchange are independent: a foreman that is not running
    still has a transcript, and losing the channel must not lose the record.
    """
    title, chat = foreman_chat(plan, chats)
    if not title:
        return {'error': 'this plan has no foreman.json, so there is nobody to write to'}
    live = bool(chat and chat.get('live') and chat.get('pid'))
    out = {'title': title, 'live': live, 'pid': (chat or {}).get('pid'), 'exchange': []}
    if chat is None:
        out['state'] = f'no chat is titled "{title}" — the foreman never opened, or it is gone'
        return out
    if not live:
        out['state'] = f'the foreman chat "{title}" is not running'
    if project_dir and chat.get('session_id'):
        out['exchange'] = transcript_tail(
            pathlib.Path(project_dir) / f"{chat['session_id']}.jsonl", limit)
    return out
