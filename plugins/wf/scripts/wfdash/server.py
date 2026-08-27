#!/usr/bin/env python3
"""The dashboard server. Listening on 127.0.0.1 only.

This process reads the work and PROPOSES; it never carries anything out. A run
belongs to `/wf:run-workflow` and the foreman channel to `refs/foreman.md`, so
a button here queues a request through `outbox.py` and the chat that opened
the dashboard serves it. No process is spawned from here and no session socket
is written.

Binding on 127.0.0.1 keeps other MACHINES out and nothing more: every process
on this host can reach the port, and the `Origin` header cannot tell them
apart — a local caller sends none at all. So the barrier is a token generated
per process and required on EVERY request, reads included. It reaches the
browser once, as a one-shot in the URL `/wf:dashboard` opens; the server
exchanges that one-shot for an `HttpOnly` cookie and invalidates it, so the
credential is never in the address bar after the first load and never in the
page's own text. Before this, `GET /` required nothing and served the token in
a `<meta>` tag: one blind request from any local process lifted it.

Endpoints:
  GET /                      the page
  GET /api/state             plan, agents, alerts, totals
  GET /api/agent?id=<id>     the turn-by-turn series of an agent
  GET /api/log?phase=<N>     the tail of a phase log
  GET /api/mirror            the foreman's state and the exchange with it
  GET /api/sessions          the chat that opened this dashboard, and the
                             live sessions on this repo it can fall back to
  GET /api/plantext?slug=&phase=  the plan's own words for one phase, verbatim
  GET /api/roadmap?macro=    the programme's own words: the whole file, or one
                             macro-phase's section of it
  POST /api/foreman          queue one message for the foreman
  POST /api/newflow          queue the command that creates a workflow
  POST /api/launch           queue an unattended run, or hand back the phase
                             command as text

The three POSTs write nothing but the queue `outbox.py` owns, outside every
working tree, and each answers with what it queued so the page can say what
was asked rather than what was done. Nothing else is recorded: the `Verify:`
steps are read from the plan and shown as text.

`/api/launch` has two roads and never picks between them: the page names the
one it pressed. The unattended road queues `/wf:run-workflow`, which owns the
pre-flight, the Monitor, the push policy, the foreman relay and the
plan-defect return leg — a spawn from here would skip all of them. The phase
road queues nothing at all: `refs/board.md` forbids starting a phase inside
the supervision chat, so the command comes back as TEXT, to be copied into a
chat of its own.

Neither road takes a recipient, a phase number or a command from the request:
the phase is the plan's own next one, and the foreman is the title
`foreman.json` names, resolved here.
"""

import argparse
import http.cookies
import http.server
import json
import os
import pathlib
import re
import secrets
import threading
import urllib.parse

import core
import inbox
import outbox
import roadmap

MAX_BODY = 64 * 1024
# The endpoints that write. One line per endpoint: a new one is added here and
# nowhere else.
WRITE_PATHS = ('/api/foreman', '/api/newflow', '/api/launch')
DEFAULT_PORT = 8787
# A phase's own block in plan.md runs from its marker line to the next one.
PHASE_LINE = re.compile(r'^- \[.\] \*\*Phase (\d+)\*\*')
BLOCK_END = re.compile(r'^(- \[.\] \*\*Phase |## )')
PORT_SPAN = 20
# The write token: generated per process and required on every request. The
# browser carries it in the cookie, the page's own fetches included; the header
# stays accepted for a caller that already holds the token. TOKEN_SLOT is the
# retired substitution slot, kept named so the tests can assert it never
# returns to index.html.
TOKEN_SLOT = '__WFDASH_TOKEN__'
TOKEN_HEADER = 'X-Wfdash-Token'
COOKIE_NAME = 'wfdash_session'
# The one-shots minted for a URL, spent on their first exchange.
ONE_SHOTS = set()
ONE_SHOTS_LOCK = threading.Lock()
# This process serves the page, so the origin is its own: the browser writes it
# `localhost` or `127.0.0.1` depending on how the page was opened.
LOCAL_HOSTS = {'127.0.0.1', 'localhost', '::1'}

HERE = pathlib.Path(__file__).parent


def new_one_shot():
    """Mint the credential that travels in the URL, once."""
    k = secrets.token_urlsafe(24)
    with ONE_SHOTS_LOCK:
        ONE_SHOTS.add(k)
    return k


def spend_one_shot(k):
    """Spend it, or refuse. A replay finds nothing: `discard` is the check."""
    if not k:
        return False
    with ONE_SHOTS_LOCK:
        if k not in ONE_SHOTS:
            return False
        ONE_SHOTS.discard(k)
    return True


class Handler(http.server.BaseHTTPRequestHandler):
    board = None
    # The chat that ran `/wf:dashboard`. None when the server was started by
    # hand, which is the same state as an owner that has since died.
    owner_pid = None
    # Generated per process. Every request must carry it back — the browser in
    # the cookie, any other caller in the header. This is what keeps other
    # PROCESSES on this machine out, which the Origin header cannot do: a
    # header is absent or forged at the caller's choice.
    token = None
    # Set on the request that spends a one-shot: the response then hands the
    # cookie over, and the address bar is clean from the next load on.
    grant = None
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):        # one line per request is noise
        pass

    def _send(self, body, ctype='application/json; charset=utf-8', code=200):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        if self.grant:
            self.send_header('Set-Cookie', f'{COOKIE_NAME}={self.grant}; '
                                           'HttpOnly; SameSite=Strict; Path=/')
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj, code=200):
        self._send(json.dumps(obj, ensure_ascii=False), code=code)

    def authenticated(self):
        """Every request, reads included. Header or cookie — one token behind both."""
        if not self.token:
            return False
        if self.headers.get(TOKEN_HEADER) == self.token:
            return True
        jar = http.cookies.SimpleCookie(self.headers.get('Cookie') or '')
        morsel = jar.get(COOKIE_NAME)
        return morsel is not None and morsel.value == self.token

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        if spend_one_shot(q.get('k', [''])[0]):
            self.grant = self.token
        elif not self.authenticated():
            return self._json({'error': 'not authenticated'}, 403)
        try:
            if u.path in ('/', '/index.html'):
                page = (HERE / 'index.html').read_text(encoding='utf-8')
                return self._send(page, 'text/html; charset=utf-8')
            if u.path == '/api/state':
                return self._json(self.board.state())
            if u.path == '/api/agent':
                return self._json(self.agent(q.get('id', [''])[0]))
            if u.path == '/api/log':
                return self._json(self.log(q))
            if u.path == '/api/mirror':
                return self._json(self.mirror())
            if u.path == '/api/sessions':
                return self._json(self.sessions())
            if u.path == '/api/plantext':
                return self._json(self.plantext(q))
            if u.path == '/api/roadmap':
                return self._json(self.roadmap(q))
            return self._json({'error': 'not found'}, 404)
        except BrokenPipeError:
            pass
        except Exception as e:                # an error must not stop the server
            return self._json({'error': f'{type(e).__name__}: {e}'}, 500)

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        try:
            # The body is read ALWAYS and first: leaving it in the socket
            # desynchronises the next request on the same connection.
            length = int(self.headers.get('Content-Length') or 0)
            if length > MAX_BODY:
                self.close_connection = True
                return self._json({'error': 'body too large'}, 413)
            raw = self.rfile.read(length)
            if u.path not in WRITE_PATHS:
                return self._json({'error': 'not found'}, 404)
            # The token first: it is the barrier that actually holds. Only the
            # page this server handed the cookie to carries it, so another
            # process on this machine cannot write even with a forged Origin —
            # and a request with no Origin at all does not walk straight through.
            if not self.authenticated():
                return self._json({'error': 'write token missing or wrong'}, 403)
            origin = self.headers.get('Origin')
            if origin and urllib.parse.urlparse(origin).hostname not in LOCAL_HOSTS:
                return self._json({'error': 'origin not allowed'}, 403)
            body = json.loads(raw or b'{}')
            if u.path == '/api/foreman':
                return self._json(self.foreman(body))
            if u.path == '/api/newflow':
                return self._json(self.newflow(body))
            if u.path == '/api/launch':
                return self._json(self.launch(body))
            return self._json({'error': 'unknown endpoint'}, 404)
        except BrokenPipeError:
            pass
        except Exception as e:
            return self._json({'error': f'{type(e).__name__}: {e}'}, 500)

    def foreman(self, body):
        """Queue one message for the foreman. The body carries text only.

        No pid, no socket path, no target of any kind comes from the request:
        the recipient is the title `foreman.json` names, resolved here so the
        request is refused now if that chat is gone, rather than in the chat
        that serves it. The delivery itself belongs to `refs/foreman.md`.
        """
        text = (body.get('text') or '').strip()
        if not text:
            return {'error': 'nothing to send'}
        plan = core.read_plan(self.board.repo)
        if plan is None:
            return {'error': 'no plan'}
        target = inbox.foreman_target(plan, self.board.agents(plan['slug']))
        if 'error' in target:
            return target
        event = outbox.append(self.board.repo, 'foreman', text=text,
                              target=target['title'])
        return {'queued': True, 'target': target['title'], 'request': event}

    def titles(self):
        """The title each chat gave itself, for the sessions the page lists."""
        return {c['session_id']: c['name'] for c in self.board.agents()
                if c.get('session_id') and c['name'] != c['session_id'][:8]}

    def sessions(self):
        """Who the first command can go to: the owner, and the list behind it."""
        titles = self.titles()
        return {'repo': self.board.repo,
                'owner': inbox.owner_target(self.owner_pid, self.board.repo, titles),
                'sessions': inbox.repo_sessions(self.board.repo, titles)}

    def mirror(self):
        """The foreman's side of the channel: its state, and what was said."""
        plan = core.read_plan(self.board.repo)
        if plan is None:
            return {'error': 'no plan'}
        return inbox.mirror(core.project_dir(self.board.repo), plan,
                            self.board.agents(plan['slug']))

    def newflow(self, body):
        """Queue the command that creates a workflow, for the chat to run."""
        name = (body.get('name') or '').strip()
        scope = (body.get('scope') or '').strip()
        if not name:
            return {'error': 'the workflow needs a name'}
        # One line, always. A newline here would deliver every following line as
        # its own instruction to the receiving session, behind the cover of the
        # command this endpoint claims to send.
        if any('\n' in v or '\r' in v for v in (name, scope)):
            return {'error': 'the name and the scope are single lines'}
        text = f'/wf:write-workflow {name}' + (f' — {scope}' if scope else '')
        event = outbox.append(self.board.repo, 'write-workflow', command=text)
        return {'queued': True, 'command': text, 'request': event}

    def launch(self, body, plan=None):
        """Propose the next phase, on the road the page pressed.

        The road is the only thing the body carries. `plan` is read from disk
        unless a caller hands one over.
        """
        plan = plan or core.read_plan(self.board.repo)
        if plan is None:
            return {'error': 'no plan'}
        if plan['next'] is None:
            blocked = plan['blocked_by']
            return {'error': f'phase {blocked} is not closed — nothing to launch' if blocked
                    else 'every phase is done'}
        if body.get('road') == 'chat':
            # `refs/board.md` forbids running a phase in the supervision chat,
            # so this road delivers nothing anywhere: it hands the command back
            # to be copied into a chat of its own.
            return {'road': 'chat', 'phase': plan['next'],
                    'command': '/wf:execute-phase'}
        event = outbox.append(self.board.repo, 'run-workflow',
                              command='/wf:run-workflow', phase=plan['next'],
                              slug=plan['slug'])
        return {'queued': True, 'road': 'unattended', 'phase': plan['next'],
                'request': event}

    def plan_source(self, slug):
        """The text of one plan.md — from disk, or out of the branch that kept it.

        A macro-phase closed long ago has no plan directory left: finalize drops
        `.phased/` from the squash, so its plan survives only on its own `wf/`
        branch. Phase 2 established that a branch is the same kind of fact as a
        directory; this reads the text where phase 2 read the markers.
        """
        for entry in core.all_plan_dirs(self.board.repo):
            if entry['slug'] == slug:
                return (pathlib.Path(entry['dir']) / 'plan.md').read_text(errors='replace')
        for entry in core.branch_plan_dirs(self.board.repo):
            if entry['slug'] == slug:
                return core.git(self.board.repo, 'show', f"{entry['branch']}:{entry['path']}")
        return None

    def plantext(self, q):
        """One phase's block of the plan, verbatim. `phase=0` is the header.

        Verbatim on purpose: the reason to open this is to compare what was
        written with what was built, and a re-rendering is the one thing that
        cannot serve that.
        """
        plan = core.read_plan(self.board.repo)
        slug = q.get('slug', [''])[0] or (plan or {}).get('slug')
        if not slug:
            return {'error': 'no plan'}
        text = self.plan_source(slug)
        if text is None:
            return {'error': f'no plan for {slug}'}
        try:
            n = int(q.get('phase', ['0'])[0])
        except ValueError:
            return {'error': 'phase is not a number'}
        lines = text.splitlines()
        if not n:
            head = []
            for line in lines:
                if line.startswith('## Work Plan') or PHASE_LINE.match(line):
                    break
                head.append(line)
            return {'slug': slug, 'phase': 0, 'lines': head}
        start = None
        for i, line in enumerate(lines):
            m = PHASE_LINE.match(line)
            if m and m.group(1) == str(n):
                start = i
                break
        if start is None:
            return {'slug': slug, 'phase': n, 'lines': [], 'missing': True}
        end = next((j for j in range(start + 1, len(lines))
                    if BLOCK_END.match(lines[j])), len(lines))
        return {'slug': slug, 'phase': n, 'lines': lines[start:end]}

    def roadmap(self, q):
        """`.phased/roadmap.md`, whole or by macro-phase section.

        The plan of a macro-phase says what that macro will do; the roadmap says
        why it comes where it does and what it owes the ones after. Neither
        replaces the other, and until now only the roadmap's title reached the
        page.
        """
        f = pathlib.Path(self.board.repo) / '.phased' / 'roadmap.md'
        if not f.is_file():
            return {'lines': [], 'missing': str(f)}
        lines = f.read_text(errors='replace').splitlines()
        want = q.get('macro', [''])[0]
        if not want:
            return {'lines': lines}
        start = next((i for i, ln in enumerate(lines)
                      if roadmap.MACRO_RE.match(ln)
                      and roadmap.MACRO_RE.match(ln).group(1) == want), None)
        if start is None:
            return {'macro': want, 'lines': [], 'missing': True}
        end = next((j for j in range(start + 1, len(lines))
                    if lines[j].startswith('## ')), len(lines))
        return {'macro': want, 'lines': lines[start:end]}

    def agent(self, ident):
        if not ident:
            return {'error': 'missing id'}
        for path, scan in self.board.scans.items():
            stem = pathlib.Path(path).stem.replace('agent-', '')
            if stem.startswith(ident):
                return {'id': ident, 'path': path, 'turns': scan.turns,
                        'series': scan.series,
                        'first_prompt': scan.first_prompt,
                        'produced': scan.last_text}
        return {'error': f'no agent for {ident}'}

    def log(self, q):
        plan = core.read_plan(self.board.repo)
        if plan is None:
            return {'error': 'no plan'}
        try:
            n = int(q.get('phase', ['0'])[0])
        except ValueError:
            return {'error': 'phase is not a number'}
        tail = min(int(q.get('tail', ['400'])[0]), 5000)
        f = pathlib.Path(plan['dir']) / 'log' / f'phase-{n}.txt'
        if not f.is_file():
            return {'phase': n, 'lines': [], 'missing': str(f)}
        with open(f, errors='replace') as fh:
            lines = fh.readlines()
        return {'phase': n, 'path': str(f), 'total': len(lines),
                'lines': [ln.rstrip('\n') for ln in lines[-tail:]]}


def serve(port, scan):
    """The listening server. `scan` walks up from `port` to the first free one.

    An explicit `-P` never scans: `.claude/launch.json` declares the port it
    will open the pane on, so a server that quietly moved would leave that
    pane pointing at nothing. Without `-P` the port is ours to choose, and
    walking up is what lets several instances coexist.
    """
    last = port + PORT_SPAN if scan else port
    for candidate in range(port, last):
        try:
            return http.server.ThreadingHTTPServer(('127.0.0.1', candidate), Handler)
        except OSError:
            pass
    return http.server.ThreadingHTTPServer(('127.0.0.1', last), Handler)


def main():
    ap = argparse.ArgumentParser(description='Dashboard of a phased workflow.')
    ap.add_argument('-C', '--cwd', default=os.getcwd(), help='the repo to watch')
    ap.add_argument('-O', '--owner', type=int, default=None,
                    help='pid of the chat that opened this dashboard; it '
                         'receives the command that creates a workflow')
    ap.add_argument('-P', '--port', type=int, default=None,
                    help=f'bind exactly this port; default: the first free one '
                         f'from {DEFAULT_PORT} up')
    args = ap.parse_args()
    Handler.board = core.Board(args.cwd)
    Handler.owner_pid = args.owner
    Handler.token = secrets.token_urlsafe(24)
    srv = serve(args.port or DEFAULT_PORT, args.port is None)
    print(f'wfdash on http://127.0.0.1:{srv.server_address[1]}/?k={new_one_shot()}'
          f'  repo: {Handler.board.repo}', flush=True)
    srv.serve_forever()


if __name__ == '__main__':
    main()
