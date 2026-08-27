#!/usr/bin/env python3
"""wfdash server: how the listening port is chosen.

Two things are asserted:

  - with no `-P` the server walks up from 8787 to the first free port, so a
    second instance coexists with the first instead of dying;
  - with an explicit `-P` it never walks: a busy port raises. `launch.json`
    declares the port its preview pane opens, and a server that quietly
    moved would leave that pane pointing at nothing.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import socket
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import server  # noqa: E402


def occupy(port):
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('127.0.0.1', port))
    s.listen(1)
    return s


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


base = free_port()
held = occupy(base)

srv = server.serve(base, True)
assert srv.server_address[1] != base, srv.server_address
assert srv.server_address[1] <= base + server.PORT_SPAN, srv.server_address
srv.server_close()

try:
    server.serve(base, False)
except OSError:
    pass
else:
    raise AssertionError('an explicit port must not walk up')

held.close()

srv = server.serve(base, False)
assert srv.server_address[1] == base, srv.server_address
srv.server_close()

assert server.DEFAULT_PORT == 8787

print('test_server ok')
