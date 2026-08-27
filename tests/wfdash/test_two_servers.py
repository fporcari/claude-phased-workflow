#!/usr/bin/env python3
"""Phase 2 contract: two dashboards on 127.0.0.1 do not evict each other.

The defect this pins, reproduced with one cookie jar across ports 8789 and
8790: the session cookie carried no port, and a browser keys cookies by host.
Open the second dashboard and the first answers 403 on its next poll — and it
cannot recover, because its one-shot was spent on the load that is now
unauthenticated. It is a regression of the graft's own Phase 1: with the token
in a `<meta>` tag every page carried its own.

Tested without a socket, through the `Probe` idiom of
`tests/wfdash/test_perimeter_closed.py`, which is also what keeps the phase
inside what `--permission-mode auto` concedes.

Four things are asserted:

  - the cookie name is derived from the port, and two ports give two names;
  - a handler on one port accepts the cookie minted for its own port;
  - the same handler REFUSES a cookie minted for the other port — this is the
    whole point: two jars, no eviction;
  - the response that grants the cookie names it with the port, so the browser
    stores two.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import server  # noqa: E402

TOKEN = 'the-real-token'


class Probe(server.Handler):
    """One handler bound to one port, with only the credential path under test."""

    def __init__(self, port, cookie=None, one_shot=None, path='/api/state'):
        self.token = TOKEN
        self.cookie_port = port
        self.path = path if one_shot is None else f'{path}?k={one_shot}'
        self.codes = []
        self.sent = []
        self.headers = {}
        if cookie is not None:
            self.headers['Cookie'] = cookie

    def send_response(self, code, *a):
        self.codes.append(code)

    def send_header(self, name, value):
        self.sent.append((name, value))

    def end_headers(self):
        pass

    @property
    def wfile(self):
        class _W:
            def write(self, *_a):
                pass
        return _W()


# --- the name carries the port ---------------------------------------------

a, b = server.cookie_name(8789), server.cookie_name(8790)
assert a != b, f'both ports produced the same cookie name: {a}'
assert '8789' in a and '8790' in b, \
    f'the cookie name does not carry the port: {a} / {b}'
print('test_two_servers: the cookie name is derived from the port ok')

# --- each port accepts its own cookie, and only its own --------------------

own = Probe(8789, cookie=f'{server.cookie_name(8789)}={TOKEN}')
own.do_GET()
assert 403 not in own.codes, \
    f'the dashboard refused the cookie minted for its own port: {own.codes}'

other = Probe(8789, cookie=f'{server.cookie_name(8790)}={TOKEN}')
other.do_GET()
assert 403 in other.codes, \
    ('the dashboard on 8789 accepted the cookie of the one on 8790 — the two '
     'still share a jar and evict each other')
print('test_two_servers: a port accepts its own cookie and refuses the other ok')

# --- the granted cookie is named with the port ----------------------------

grant = Probe(8789, one_shot=server.new_one_shot(), path='/api/state')
grant.do_GET()
cookies = [v for n, v in grant.sent if n == 'Set-Cookie']
assert cookies, f'the one-shot exchange set no cookie: {grant.sent}'
assert server.cookie_name(8789) in cookies[0], \
    f'the granted cookie is not named with the port: {cookies[0]}'
assert server.RETIRED_COOKIE_NAME not in cookies[0], \
    f'the retired bare cookie name is back in the response: {cookies[0]}'
print('test_two_servers: the granted cookie carries the port in its name ok')

print('test_two_servers ok')
