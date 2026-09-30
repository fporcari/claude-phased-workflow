#!/usr/bin/env python3
"""`--detach`: the server outlives the tool call that started it.

The defect this pins: Claude Code 2.1.285 stops a `run_in_background` Bash
command after its time limit, and `/wf:dashboard` started the server exactly
that way — the page lost its data source half an hour in, silently. With
`--detach` the call returns as soon as the URL line is out, and the server
keeps serving from a session of its own.

Four things are asserted, against a real process and socket:

  - the call returns, exit 0, with the `wfdash on …?k=` line on its stdout;
  - the registry names a pid that is NOT the one that returned, in a session
    of its own;
  - that server answers `--probe` for this repository;
  - a group kill on the registered pid stops it.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time

SERVER = (pathlib.Path(__file__).resolve().parents[2]
          / 'plugins' / 'wf' / 'scripts' / 'wfdash' / 'server.py')

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-detach-'))
repo = tmp / 'repo'
repo.mkdir()
env = dict(os.environ, TMPDIR=str(tmp))

started = subprocess.run([sys.executable, str(SERVER), '--detach', '-C', str(repo),
                          '-P', '0'], env=env, capture_output=True, text=True,
                         timeout=10)
assert started.returncode == 0, started
line = started.stdout.splitlines()[0]
assert line.startswith('wfdash on http://127.0.0.1:') and '?k=' in line, started.stdout
print('test_detach: the call returns with the URL line ok')

reg = next((tmp / f'phased-workflow-{os.getuid()}').glob('*-server.json'))
pid = json.loads(reg.read_text())['pid']
try:
    assert line.endswith(f'  pid {pid}'), f'the URL line does not name the server pid: {line}'
    assert os.getsid(pid) == pid, 'the server is not the leader of its own session'
    assert os.getsid(pid) != os.getsid(0), 'the server shares the caller session'
    print('test_detach: the registered server runs in a session of its own ok')

    probed = subprocess.run([sys.executable, str(SERVER), '--probe', '-C', str(repo)],
                            env=env, capture_output=True, text=True, timeout=10)
    assert probed.returncode == 0 and f'reused, pid {pid}' in probed.stdout, probed
    print('test_detach: the detached server answers the probe ok')
finally:
    os.killpg(pid, signal.SIGTERM)

deadline = time.monotonic() + 5
while time.monotonic() < deadline:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        break
    time.sleep(.05)
else:
    raise AssertionError('the detached server survived a group kill')
print('test_detach: a group kill stops it ok')

print('test_detach ok')
