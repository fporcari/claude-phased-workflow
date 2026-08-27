#!/usr/bin/env python3
"""wfdash launch: what is queued, what is handed back, and what refuses.

The server proposes and the chat acts, so nothing here starts a process: what
is asserted is the REQUEST each road leaves behind.

Five things are asserted:

  - the unattended road queues one `/wf:run-workflow` request naming the
    plan's own next phase, and reports what it queued;
  - a second press queues a second request rather than refusing: there is no
    child to collide with any more, and the chat that drains the queue is the
    one place that knows whether a run is already going;
  - the phase road queues NOTHING and hands back the command to copy — the
    supervision chat is not where a phase runs;
  - a plan with nothing eligible refuses before either road is chosen;
  - the queue file is keyed by repository and lives outside it.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import shutil
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import outbox  # noqa: E402
import server  # noqa: E402

tmp = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-launch-'))


class Fake:
    """The handler's launch method, with the one attribute it reads."""

    launch = server.Handler.launch

    def __init__(self, repo_root):
        self.board = type('B', (), {'repo': str(repo_root)})()
        self.owner_pid = None


def with_plan(name, body):
    root = tmp / name
    (root / '.phased' / 'active' / name).mkdir(parents=True)
    (root / '.phased' / 'active' / name / 'plan.md').write_text(body)
    outbox.truncate(root)
    return Fake(root)


# --- the unattended road queues the run ----------------------------------
open_plan = with_plan('open', '- [x] **Phase 1**: a\n- [ ] **Phase 2**: b\n')
answer = open_plan.launch({'road': 'unattended'})
assert 'error' not in answer, answer
assert answer['queued'] is True and answer['phase'] == 2, answer
queued = outbox.read(open_plan.board.repo)
assert len(queued) == 1, queued
assert queued[0]['kind'] == 'run-workflow', queued[0]
assert queued[0]['command'] == '/wf:run-workflow', queued[0]
assert queued[0]['slug'] == 'open', queued[0]

# A second press is a second request: nothing is spawned here, so there is no
# child to guard against — the chat serving the queue owns that decision.
open_plan.launch({'road': 'unattended'})
assert len(outbox.read(open_plan.board.repo)) == 2, outbox.read(open_plan.board.repo)

# --- the phase road delivers nothing -------------------------------------
outbox.truncate(open_plan.board.repo)
answer = open_plan.launch({'road': 'chat'})
assert answer['command'] == '/wf:execute-phase' and answer['phase'] == 2, answer
assert 'queued' not in answer and 'pid' not in answer, answer
assert outbox.read(open_plan.board.repo) == [], 'the phase road queued something'

# --- nothing eligible, through the endpoint's own plan read ---------------
# `launch` resolves the phase from the plan on disk: the page names a road and
# nothing else, so the refusals are asserted against real plan files.
stuck = with_plan('stuck', '- [!] **Phase 3**: broken\n- [ ] **Phase 4**: next\n')
answer = stuck.launch({'road': 'unattended'})
assert 'error' in answer and 'phase 3 is not closed' in answer['error'], answer
assert outbox.read(stuck.board.repo) == [], 'a refusal must not queue a run'

closed = with_plan('closed', '- [x] **Phase 1**: a\n- [x] **Phase 2**: b\n')
answer = closed.launch({'road': 'unattended'})
assert 'error' in answer and 'every phase is done' in answer['error'], answer

# --- the queue is per repository, and outside it -------------------------
assert outbox.path(open_plan.board.repo) != outbox.path(stuck.board.repo)
for fake in (open_plan, stuck, closed):
    q = str(outbox.path(fake.board.repo))
    assert not q.startswith(str(pathlib.Path(fake.board.repo).resolve())), q
    outbox.truncate(fake.board.repo)

shutil.rmtree(tmp, ignore_errors=True)

print('test_launch ok')
