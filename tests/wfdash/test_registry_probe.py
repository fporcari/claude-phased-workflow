#!/usr/bin/env python3
"""Discovery through the registry: reuse works with every read authenticated.

The defect this pins: `/wf:dashboard`'s Step 2 curled `/api/state` bare on
every listening port, and the server answers 403 to an unauthenticated GET —
so the discovery recognised nothing, the `one server per repository` promise
was dead, and every open started a twin. Now the server writes a registry
entry beside its queue (port, pid, token — 0600), and `--probe` reads it,
confirms over the AUTHENTICATED endpoints that the server still answers for
this repository, and mints a fresh one-shot so the reused page can actually
be opened.

Five things are asserted, against a real socket:

  - `probe` finds the live server and returns port and a spendable one-shot;
  - the registry file is 0600;
  - a repository with no entry probes as None;
  - a stale entry — the server is gone — probes as None AND is removed;
  - `drop_registry` removes only its own pid's entry.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import os
import pathlib
import secrets
import stat
import sys
import tempfile
import threading

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core     # noqa: E402
import outbox   # noqa: E402
import server   # noqa: E402

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-registry-'))
outbox.TMP = tmp / 'phased-workflow'
repo = tmp / 'repo'
repo.mkdir()

# The server, wired the way main() wires it, on an OS-assigned port.
server.Handler.board = core.Board(str(repo))
server.Handler.token = secrets.token_urlsafe(24)
srv = server.serve(0, False)
port = srv.server_address[1]
server.Handler.cookie_port = port
server.write_registry(server.Handler.board.repo, port, server.Handler.token)
threading.Thread(target=srv.serve_forever, daemon=True).start()

# --- the live server is found, with a spendable one-shot -------------------

found = server.probe(str(repo))
assert found, 'the probe did not find the live server'
assert found['port'] == port, found
assert found['pid'] == os.getpid(), found
assert server.spend_one_shot(found['k']), \
    'the one-shot the probe minted cannot be spent: the reused page stays out'
print('test_registry_probe: the live server is found and lets a page in ok')

reg = server.registry_path(str(repo))
assert stat.S_IMODE(os.stat(reg).st_mode) == 0o600, \
    f'the registry carries the token and is {oct(stat.S_IMODE(os.stat(reg).st_mode))}'
print('test_registry_probe: the registry file is 0600 ok')

# --- no entry, no server ----------------------------------------------------

other = tmp / 'other'
other.mkdir()
assert server.probe(str(other)) is None, 'a repository with no entry probed as live'
print('test_registry_probe: no entry probes as None ok')

# --- a stale entry is refused and removed -----------------------------------

srv.shutdown()
srv.server_close()
assert server.probe(str(repo)) is None, 'a dead server probed as live'
assert not reg.exists(), 'the stale registry entry was not removed'
print('test_registry_probe: a stale entry is refused and removed ok')

# --- drop_registry removes only its own --------------------------------------

server.write_registry(str(repo), port, 'tok')
server.drop_registry(str(repo), os.getpid() + 1)      # somebody else's pid
assert reg.exists(), 'drop_registry removed an entry that was not its own'
server.drop_registry(str(repo), os.getpid())
assert not reg.exists(), 'drop_registry left its own entry behind'
print('test_registry_probe: drop_registry removes only its own entry ok')

print('test_registry_probe ok')
