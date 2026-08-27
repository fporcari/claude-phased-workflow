#!/usr/bin/env python3
"""Phase 8 contract: what promises and does not deliver is gone.

Three surfaces that cost a reader something and give nothing back:

  - `parse_plan` / `parse_plan_text` only unpack `selection()`. A wrapper that
    just delegates is the named anti-pattern, and here it also hides which of
    the payload's fields a call site actually wants;
  - `wHeaders()` has added no header since the cookie moved out of the page: a
    constant returned through three call sites under a name that promises
    otherwise;
  - `GET /api/agent` is routed and authenticated with no caller anywhere —
    inherited from the delivered source, not orphaned by a phase. An
    authenticated surface nobody calls is surface nobody checks.

The fourth assertion is the one that says what may NOT change: an
unauthenticated request to `/api/agent` must still be refused. The credential is
checked before the routing, so deleting the route must leave a stranger with a
403 and not a 404 — that ordering is the perimeter.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WFDASH = ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'
sys.path.insert(0, str(WFDASH))
import server  # noqa: E402

# --- no wrapper that only delegates --------------------------------------

for name in ('parse_plan', 'parse_plan_text'):
    hits = [str(f) for f in sorted(WFDASH.glob('*.py'))
            if name in f.read_text()]
    assert not hits, f'{name} is still there: {hits}'
    hits = [str(f) for f in sorted((ROOT / 'tests' / 'wfdash').glob('*.py'))
            if f'core.{name}' in f.read_text()]
    assert not hits, f'{name} still has callers in the tests: {hits}'
print('test_no_wrappers: parse_plan / parse_plan_text are gone ok')

# --- no constant behind a name that promises a header --------------------

page = (WFDASH / 'index.html').read_text()
assert 'wHeaders' not in page, \
    'wHeaders() is still in the page: it adds no header'
print('test_no_wrappers: wHeaders is gone ok')

# --- no authenticated endpoint without a caller -------------------------

source = (WFDASH / 'server.py').read_text()
assert '/api/agent' not in source, \
    'the /api/agent route is still there and still has no caller'
assert not hasattr(server.Handler, 'agent'), \
    'Handler.agent() survived the route it served'
print('test_no_wrappers: the caller-less /api/agent endpoint is gone ok')

# --- and the perimeter is unchanged: a stranger still gets 403 ----------


class Probe(server.Handler):
    """No socket: only the ordering of credential check and routing is tested."""

    def __init__(self, path):
        self.token = 'the-real-token'
        self.cookie_port = 8787
        self.path = path
        self.codes = []
        self.headers = {}

    def send_response(self, code, *a):
        self.codes.append(code)

    def send_header(self, *a, **k):
        pass

    def end_headers(self):
        pass

    @property
    def wfile(self):
        class _W:
            def write(self, *_a):
                pass
        return _W()


probe = Probe('/api/agent')
probe.do_GET()
assert 403 in probe.codes, \
    (f'a deleted route answered {probe.codes} to an unauthenticated caller: '
     'the credential must be checked before the routing')
print('test_no_wrappers: a stranger still gets 403, not 404 ok')

print('test_no_wrappers ok')
