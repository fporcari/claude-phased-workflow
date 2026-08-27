#!/usr/bin/env python3
"""Phase 1 contract: no request reaches this server unauthenticated.

The hole this phase closes, demonstrated against the running server before the
plan was written: `GET /` required nothing and served the write token in clear
in a `<meta>` tag, so any local process lifted it with one request and wrote
with the next. The module docstring and the perimeter test both claimed that
could not happen.

Tested WITHOUT a socket, through the existing `FakeHandler` idiom
(`tests/wfdash/test_perimeter.py`), so this file starts no server and issues no
HTTP request — which is also what keeps every phase inside what
`--permission-mode auto` concedes.

Four things are asserted:

  - the page carries NO token: the `<meta name="wfdash-token">` slot is gone
    from index.html, and the served page never contains the token value;
  - a GET with no credential is refused — the request that used to hand the
    token out, and every read endpoint behind it;
  - a GET carrying the cookie is served;
  - the one-shot is single-use: replayed, it no longer authenticates.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import server  # noqa: E402

PAGE = (ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash' / 'index.html').read_text()

# --- the page holds no token ------------------------------------------------

assert 'name="wfdash-token"' not in PAGE, \
    'the meta slot is still there: GET / would hand the token to any local process'
assert server.TOKEN_SLOT not in PAGE, \
    f'the substitution slot {server.TOKEN_SLOT} is still in the page'

# --- a GET with no credential is refused -----------------------------------


class Probe(server.Handler):
    """The perimeter without a socket: only the credential check is under test."""

    def __init__(self, cookie=None, one_shot=None, path='/api/state', port=8789):
        self.token = 'the-real-token'
        self.cookie_port = port
        self.path = path if one_shot is None else f'{path}?k={one_shot}'
        self.codes = []
        self.body = []
        self.headers = {}
        if cookie is not None:
            self.headers['Cookie'] = f'{server.cookie_name(port)}={cookie}'

    def send_response(self, code, *a):
        self.codes.append(code)

    def send_header(self, *a, **k):
        pass

    def end_headers(self):
        pass

    @property
    def wfile(self):
        body = self.body

        class _W:
            def write(self, chunk):
                body.append(chunk)
        return _W()


for path in ('/', '/api/state', '/api/agent', '/api/log', '/api/mirror',
             '/api/sessions', '/api/plantext', '/api/roadmap'):
    probe = Probe(path=path)
    probe.do_GET()
    assert 403 in probe.codes, \
        f'{path} answered {probe.codes} without a credential — it must refuse'
print('test_perimeter_closed: every GET refuses an unauthenticated request ok')

# --- a GET carrying the cookie is served -----------------------------------

probe = Probe(cookie='the-real-token', path='/api/state')
probe.do_GET()
assert 403 not in probe.codes, \
    f'a GET carrying the cookie was refused: {probe.codes}'
print('test_perimeter_closed: the cookie is accepted ok')

# --- the one-shot is single-use -------------------------------------------

one_shot = server.new_one_shot()
first = Probe(one_shot=one_shot, path='/')
first.do_GET()
assert 403 not in first.codes, f'the one-shot did not authenticate: {first.codes}'

replay = Probe(one_shot=one_shot, path='/')
replay.do_GET()
assert 403 in replay.codes, \
    'the one-shot authenticated twice — it must be invalidated on the exchange'
print('test_perimeter_closed: the one-shot is single-use ok')

# --- the refusal a PERSON reads ---------------------------------------------
# Copying the URL out of the pane into another browser lands here: the `?k=`
# was spent by the pane's first load and the cookie that replaced it lives in
# that browser alone. Reported as a bare `{"error": "not authenticated"}` it
# reads as a broken dashboard; the page path answers in prose with the way
# back in, and names neither the repository nor the port — an unauthenticated
# answer must not say what this server watches.

page = Probe(path='/')
page.do_GET()
text = b''.join(page.body).decode()
assert 403 in page.codes, page.codes
assert 'already been used' in text, text[:200]
assert '/wf:dashboard' in text and '--probe' in text, \
    'the refusal does not say how to get back in'
assert str(page.cookie_port) not in text, \
    'the unauthenticated refusal names the port it listens on'
assert '&lt;repo&gt;' in text, \
    'the refusal spells out a repository instead of leaving a placeholder'

api = Probe(path='/api/state')
api.do_GET()
assert 'not authenticated' in b''.join(api.body).decode(), \
    'an API path stopped answering JSON — its callers are machines'
print('test_perimeter_closed: the page refusal is readable, the API stays JSON ok')

print('test_perimeter_closed ok')
