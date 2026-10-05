#!/usr/bin/env python3
"""wfdash on a worktree plan: the chats live in the main checkout.

`/write-workflow` opens a manual or autonomous plan in `.claude/worktrees/<slug>`,
while its foreman — and usually its worker, opened with the project's + — sit
in the main checkout. The dashboard watches the worktree, so:

  - `checkouts` names the worktree, then the main checkout it hangs from;
  - a session in the main checkout is accepted as the owner and offered as a
    recipient; one in an unrelated repo still is not;
  - `Board.agents` reads the main checkout's transcripts too, but only the
    chats titled for this plan: the rest of that project is not this workflow;
  - the mirror finds the foreman's transcript there.

A real git repo and worktree in a temp dir; `claude agents --json` is replaced
by a fixed dictionary. Bare asserts, no framework: exit 0 clean, raises on the
first failure.
"""
import json
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402
import inbox  # noqa: E402

PLAN = """# Context: wf/foo
Mode: manual

## Work Plan
- [x] **Phase 1**: first
- [ ] **Phase 2**: second
"""


def git(cwd, *args):
    subprocess.run(['git', '-C', str(cwd), *args], check=True, capture_output=True)


def chat(project, sid, title):
    rows = [{'type': 'custom-title', 'customTitle': title},
            {'type': 'assistant', 'timestamp': '2026-10-04T09:00:00Z',
             'message': {'model': 'claude-opus-5-5', 'content': [{'type': 'text', 'text': 'ok'}],
                         'usage': {'input_tokens': 1, 'output_tokens': 1}}}]
    (project / f'{sid}.jsonl').write_text('\n'.join(json.dumps(r) for r in rows) + '\n')


with tempfile.TemporaryDirectory() as td:
    tmp = pathlib.Path(td)
    main = tmp / 'main'
    main.mkdir()
    git(main, 'init', '-q', '-b', 'develop')
    git(main, '-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '--allow-empty', '-m', 'root')
    wt = main / '.claude' / 'worktrees' / 'foo'
    git(main, 'worktree', 'add', '-q', str(wt), '-b', 'wf/foo')
    (wt / '.phased' / 'active' / 'foo').mkdir(parents=True)
    (wt / '.phased' / 'active' / 'foo' / 'plan.md').write_text(PLAN)

    homes = core.checkouts(str(wt))
    assert [pathlib.Path(p).resolve() for p in homes] == [wt.resolve(), main.resolve()], homes
    assert len(core.checkouts(str(main))) == 1, core.checkouts(str(main))

    inbox.SESSIONS = tmp / 'sessions'
    inbox.SESSIONS.mkdir()
    (inbox.SESSIONS / '501.json').write_text(json.dumps({'pid': 501, 'sessionId': 'fore', 'cwd': str(main)}))
    (inbox.SESSIONS / '502.json').write_text(json.dumps({'pid': 502, 'sessionId': 'away', 'cwd': str(tmp / 'other')}))
    owner = inbox.owner_target(501, str(wt))
    assert owner and owner['session_id'] == 'fore', owner
    assert inbox.owner_target(502, str(wt)) is None

    core.live_sessions = lambda: {
        'fore': {'pid': 501, 'cwd': str(main), 'startedAt': 2},
        'away': {'pid': 502, 'cwd': str(tmp / 'other'), 'startedAt': 3},
    }
    assert [s['session_id'] for s in inbox.repo_sessions(str(wt))] == ['fore']

    core.PROJECTS = tmp / 'projects'
    main_project = core.PROJECTS / str(main).replace('/', '-').replace('.', '-')
    main_project.mkdir(parents=True)
    chat(main_project, 'fore', 'wf:foo:foreman')
    chat(main_project, 'work', 'wf:foo:phase-2')
    chat(main_project, 'else', 'an unrelated chat on the project')
    chat(main_project, 'bar', 'wf:bar:phase-1')
    board = core.Board(str(wt))
    seen = {c['session_id']: c for c in board.agents('foo')}
    assert sorted(seen) == ['fore', 'work'], sorted(seen)
    assert seen['work']['phase'] == 2, seen['work']

    plan = {'slug': 'foo', 'foreman': {'foreman': 'wf:foo:foreman'}}
    dirs = [core.project_dir(c) for c in core.checkouts(str(wt))]
    m = inbox.mirror(dirs, plan, board.agents('foo'))
    assert m['title'] == 'wf:foo:foreman' and m['live'] is True, m

    # Since 6.49.0 the role leads and the plan's theme ends the title; the
    # pre-6.49.0 titles of the same plan still count.
    chat(main_project, 'fore', 'Foreman · Foo UI')
    chat(main_project, 'next', 'Worker P3 · Foo UI')
    chat(main_project, 'them', 'Worker P3 · Bar UI')
    board = core.Board(str(wt))
    seen = {c['session_id']: c for c in board.agents('foo', theme='Foo UI')}
    assert sorted(seen) == ['fore', 'next', 'work'], sorted(seen)
    assert seen['next']['phase'] == 3 and seen['fore']['role'] == 'foreman', seen
    assert core.chat_title('Deposed · Foo UI') == {'key': 'Foo UI', 'role': 'deposed', 'n': None}
    assert core.chat_title('an unrelated chat') is None
