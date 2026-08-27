#!/usr/bin/env python3
"""wfdash core: attributing a phase whose chat never took a title.

A phase run unattended has no titled chat, so `TITLE_PHASE_RE` says nothing
and its row reads `—`. The commits say when it ran instead. This builds a real
git repo with dated commits and a fake ~/.claude/projects tree, then asserts:

  - the window of a phase opens at the previous phase's last commit and closes
    at its own last one; a non-phase `wf:` commit bounds nothing;
  - a `[>]` phase, having no closing commit, keeps an open window;
  - a transcript is placed by its FIRST assistant row — its last row falls
    after the phase commit, which is what closing a phase does;
  - the timestamps are compared as instants: the transcripts are written in
    UTC (`Z`) and the commits with a `+02:00` offset, so comparing the strings
    would attribute by offset and put the phase-2 chat on phase 1;
  - three transcripts stay unattributed, because a wrong attribution is worse
    than a missing one: one outside every window, one that ran in another
    directory, and one whose start sits exactly on a window boundary;
  - a chat that declared itself — any `wf:` title, this plan's or another's —
    is never re-attributed by window.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import os
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402

PLAN = """# Context: wf/myplan
Mode: interactive

## Work Plan
- [x] **Phase 1**: first phase
  - Run: opus / medium
- [x] **Phase 2**: second phase
  - Run: opus / medium
- [>] **Phase 3**: third phase
  - Run: opus / high
"""

# Local time, the offset git prints. The windows: phase 1 08:00 -> 09:00,
# phase 2 09:00 -> 11:00, phase 3 11:00 -> open.
T_PLAN = '2026-08-25T08:00:00+02:00'
T_CLARIFY = '2026-08-25T08:30:00+02:00'
T_P1 = '2026-08-25T09:00:00+02:00'
T_P2_PARTIAL = '2026-08-25T10:00:00+02:00'
T_P2 = '2026-08-25T11:00:00+02:00'
# Phase 3 is still `[>]` and has already committed a partial. Its window must
# stay OPEN anyway: the phase is running, so chats opened after this commit
# still belong to it — a long phase and a repair both do exactly that.
T_P3_PARTIAL = '2026-08-25T12:00:00+02:00'

# UTC, the way a transcript row is written. 07:30Z is 09:30+02:00.
BEFORE_PLAN = '2026-08-25T05:00:00.000Z'
IN_P2 = '2026-08-25T07:30:00.000Z'
AFTER_P2 = '2026-08-25T09:30:00.000Z'
AFTER_P3_PARTIAL = '2026-08-25T10:30:00.000Z'   # 12:30+02:00, past the partial
ON_BOUNDARY = '2026-08-25T07:00:00.000Z'    # exactly T_P1


def git(repo, *args, when=None):
    env = dict(os.environ)
    if when:
        env['GIT_AUTHOR_DATE'] = env['GIT_COMMITTER_DATE'] = when
    subprocess.run(['git', '-C', str(repo), *args], check=True, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def commit(repo, message, when):
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', message, when=when)


def assistant_row(ts, cwd, out=100):
    return json.dumps({
        'type': 'assistant', 'timestamp': ts, 'cwd': str(cwd),
        'message': {'model': 'claude-opus-5',
                    'content': [{'type': 'text', 'text': 'done'}],
                    'usage': {'input_tokens': 10, 'output_tokens': out,
                              'cache_read_input_tokens': 1000}}})


def write_chat(project, sid, title, cwd, stamps, subagent=None):
    rows = [json.dumps({'type': 'custom-title', 'customTitle': title})] if title else []
    rows += [assistant_row(ts, cwd) for ts in stamps]
    (project / f'{sid}.jsonl').write_text('\n'.join(rows) + '\n')
    if subagent:
        d = project / sid / 'subagents'
        d.mkdir(parents=True, exist_ok=True)
        (d / f'agent-{subagent}.meta.json').write_text(
            json.dumps({'agentType': 'Explore', 'description': 'look around', 'spawnDepth': 1}))
        (d / f'agent-{subagent}.jsonl').write_text(assistant_row(stamps[0], cwd, out=50) + '\n')


def build(tmp):
    repo = tmp / 'gitrepo'
    plan_dir = repo / '.phased' / 'active' / 'myplan'
    plan_dir.mkdir(parents=True)
    (plan_dir / 'plan.md').write_text(PLAN)
    # Attribution by window exists for phases that ran UNATTENDED, and that is
    # what leaves these logs. Without one a phase gets no window at all, so an
    # open window cannot swallow the owner's own interactive chat.
    (plan_dir / 'log').mkdir()
    for n in (1, 2, 3):
        (plan_dir / 'log' / f'phase-{n}.txt').write_text(f'phase {n} ran unattended\n')
    git(tmp, 'init', '-q', '-b', 'main', str(repo))
    git(repo, 'config', 'user.email', 'test@example.invalid')
    git(repo, 'config', 'user.name', 'test')
    commit(repo, 'wf: plan for myplan', T_PLAN)
    (repo / 'a.txt').write_text('one\n')
    commit(repo, 'wf: clarify phase 1 — a non-phase commit bounds nothing', T_CLARIFY)
    (repo / 'a.txt').write_text('two\n')
    commit(repo, 'wf(phase 1): first phase', T_P1)
    (repo / 'a.txt').write_text('three\n')
    commit(repo, 'wf(phase 2): partial — half way', T_P2_PARTIAL)
    (repo / 'a.txt').write_text('four\n')
    commit(repo, 'wf(phase 2): second phase', T_P2)
    (repo / 'a.txt').write_text('five\n')
    commit(repo, 'wf(phase 3): partial — still running', T_P3_PARTIAL)

    slug = str(repo).replace('/', '-').replace('_', '-').replace('.', '-')
    project = tmp / 'projects' / slug
    project.mkdir(parents=True)
    elsewhere = tmp / 'another-repo'
    # the title wins even though the window would say phase 2
    write_chat(project, 'aaaa1111', 'wf:myplan:phase-1', repo, [IN_P2])
    # the unattended phase: starts inside phase 2, still writing after its commit
    write_chat(project, 'bbbb2222', None, repo, [IN_P2, AFTER_P2], subagent='9999aaaa')
    write_chat(project, 'cccc3333', None, repo, [BEFORE_PLAN])          # outside every window
    write_chat(project, 'dddd4444', None, elsewhere, [IN_P2])           # another directory
    write_chat(project, 'eeee5555', 'wf:otherplan:phase-2', repo, [IN_P2])
    write_chat(project, 'ffff6666', None, repo, [AFTER_P2])             # the [>] open window
    write_chat(project, 'gggg7777', None, repo, [ON_BOUNDARY])          # two windows claim it
    # started after phase 3's own partial commit, while the phase is still [>]
    write_chat(project, 'hhhh8888', None, repo, [AFTER_P3_PARTIAL])
    return repo, project


def main():
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td)
        repo, _ = build(tmp)
        core.PROJECTS = tmp / 'projects'
        core.live_sessions = lambda: {}
        state = core.Board(str(repo)).state()

        windows = core.phase_windows(str(repo), state['plan'])
        assert sorted(windows) == [1, 2, 3], windows
        assert windows[1][0] == core._when(T_PLAN), windows[1]
        assert windows[1][1] == core._when(T_P1), windows[1]
        assert windows[2] == (core._when(T_P1), core._when(T_P2)), windows[2]
        assert windows[3] == (core._when(T_P2), None), windows[3]

        by_id = {c['session_id']: c for c in state['chats']}
        assert by_id['aaaa1111']['phase'] == 1
        assert by_id['aaaa1111']['phase_from'] == 'title'
        assert by_id['bbbb2222']['phase'] == 2, by_id['bbbb2222']['phase']
        assert by_id['bbbb2222']['phase_from'] == 'window'
        assert by_id['ffff6666']['phase'] == 3
        assert by_id['ffff6666']['phase_from'] == 'window'
        # phase 3 committed a partial and is still [>]: a chat opened after that
        # commit is still its work, not off-plan
        assert by_id['hhhh8888']['phase'] == 3, by_id['hhhh8888']['phase']
        assert by_id['hhhh8888']['phase_from'] == 'window'
        for sid in ('cccc3333', 'dddd4444', 'eeee5555', 'gggg7777'):
            assert by_id[sid]['phase'] is None, sid
            assert by_id[sid]['phase_from'] is None, sid
        assert by_id['eeee5555']['plan_slug'] == 'otherplan'

        # a subagent inherits the inference of the chat that spawned it
        sub = by_id['bbbb2222']['subagents'][0]
        assert sub['phase'] == 2 and sub['phase_from'] == 'window', sub

        # sorted per phase: the order inside a phase is by mtime, not a contract
        assert {k: sorted(v) for k, v in state['groups']['by_phase'].items()} == {
            '1': ['aaaa1111'], '2': ['bbbb2222'],
            '3': ['ffff6666', 'hhhh8888']}, state['groups']['by_phase']
        assert sorted(state['groups']['off_plan']) == ['cccc3333', 'dddd4444', 'eeee5555', 'gggg7777']

        # No unattended log, no window. This is what keeps an open window from
        # claiming the owner's own interactive chat in the repo: without the
        # log there is nothing to claim it with.
        plan_dir = pathlib.Path(state['plan']['dir'])
        (plan_dir / 'log' / 'phase-3.txt').unlink()
        narrowed = core.phase_windows(str(repo), state['plan'])
        assert sorted(narrowed) == [1, 2], narrowed
        for f in (plan_dir / 'log').iterdir():
            f.unlink()
        assert core.phase_windows(str(repo), state['plan']) == {}, 'a window survived with no log'
    print('test_attribution: ok')


if __name__ == '__main__':
    main()
