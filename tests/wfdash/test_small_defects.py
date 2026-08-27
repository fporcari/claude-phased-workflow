#!/usr/bin/env python3
"""Phase 4 contract: the three small correctness defects that have a witness.

Three of the four defects this phase closes can be pinned from outside:

  - the token is compared in constant time. There is no observable behaviour to
    assert — a timing-safe comparison answers exactly what `==` answers — so the
    comparison itself is the contract, and the source is where it is stated. The
    module already imports `secrets`;
  - `self.grant` is cleared once the cookie has been handed over. Under HTTP/1.1
    keep-alive the handler instance outlives the response, so every later
    response on the same connection repeated `Set-Cookie`. Harmless with one
    process-wide token, a leak of the previous grant the day it is per-request;
  - a `>` note that follows a `## ` heading attaches to NO phase. That is S18
    inertness — a prose bullet in `## Notes` may never be read as plan state —
    and until now nothing pinned it.

The fourth (a payload of the wrong shape must degrade to "no plan" rather than
raise) has no seam from outside the reader and is stated as a skeleton in
`test_selection_shape.py`.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WFDASH = ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'
sys.path.insert(0, str(WFDASH))
import core  # noqa: E402
import server  # noqa: E402

SOURCE = (WFDASH / 'server.py').read_text()

# --- the token is compared in constant time -------------------------------

assert 'compare_digest' in SOURCE, \
    'the token is still compared with ==: use secrets.compare_digest'
assert '== self.token' not in SOURCE, \
    'a plain == comparison against the token is still there'
print('test_small_defects: the token is compared in constant time ok')

# --- the grant is spent once ----------------------------------------------


class Probe(server.Handler):
    """Two responses on one handler, the way keep-alive delivers them."""

    def __init__(self):
        self.token = 'the-real-token'
        self.cookie_port = 8787
        self.codes = []
        self.sent = []
        self.headers = {}
        self.path = '/api/state'

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


probe = Probe()
probe.grant = probe.token
probe._send('{}')
first = [v for n, v in probe.sent if n == 'Set-Cookie']
assert len(first) == 1, f'the granting response set {len(first)} cookies'

probe.sent = []
probe._send('{}')
later = [v for n, v in probe.sent if n == 'Set-Cookie']
assert later == [], \
    ('a later response on the same connection repeated Set-Cookie: the grant '
     f'was never cleared — {later}')
print('test_small_defects: the grant is handed over once and cleared ok')

# --- a note after a ## heading attaches to no phase -----------------------

PLAN = """# Context: wf/toy
Parent: main
Mode: autonomous

## Objective
A plan whose Notes section carries a decoy.

## Work Plan
- [ ] **Phase 1**: the only phase
  - Verify: now — the real one
  > Review: attached to the phase
  - Done: nothing

## Notes
> Review: a decoy that belongs to no phase
"""

sel = core.selection(text=PLAN)
assert sel is not None, 'the reader refused a well-formed plan'
assert len(sel['phases']) == 1, f"expected one phase, got {len(sel['phases'])}"
phase = sel['phases'][0]
texts = [n['text'] for n in phase['notes']]
assert any('attached to the phase' in t for t in texts), \
    f'the phase lost its own note: {texts}'
assert not any('decoy' in t for t in texts), \
    ('a note written after a ## heading attached itself to the last phase: '
     f'{texts}')
assert len(phase['verify']) == 1, \
    f"the phase's Verify list changed shape: {phase['verify']}"
print('test_small_defects: a note after a ## heading attaches to no phase ok')

print('test_small_defects ok')
