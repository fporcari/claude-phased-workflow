#!/usr/bin/env python3
"""wfdash steps: the agent's own todo list, and the workflow's lifecycle.

Two readings, both from fixtures on disk:

  - the todo list of a session — `~/.claude/tasks/<sessionId>/N.json` — with
    its statuses mixed and `10.json` after `9.json`; a `completed` item that
    goes back to `in_progress` lowers the count, because a retreat is a thing
    to show and not an anomaly to hide; a session that never wrote a todo
    reads as None, which the page says as "no declaration" and never as 0%;
  - the same list reaching the page: the panel of a chat that declared one
    carries its counts, the panel of a chat that did not carries None;
  - a finalized workflow found where it actually survives — its `done/`
    directory, or the `wf/` branch that kept it once finalize dropped
    `.phased/` from the squash. Without it the last stage can never light;
  - the lifecycle of a workflow in each of its four measurable states: the
    plan commit, every phase closed, the quality stamp, the plan directory
    under `.phased/done/`. The stamp counts only under its own heading: the
    same words inside a phase note are a phase talking about the check.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402

RUNNING = """# Context: wf/steps
Mode: interactive

## Work Plan
- [x] **Phase 1**: first
  - Run: opus / medium
- [>] **Phase 2**: second
  > Quality check: a phase note quoting the stamp is not the stamp
  - Run: opus / medium
"""

CLOSED = RUNNING.replace('- [>] **Phase 2**', '- [x] **Phase 2**')

STAMPED = CLOSED + """
## Quality check
> Quality check: 2026-08-26T09:00:00Z — commit abc1234 — review extended, QA done, findings none
"""

TODOS = [
    ('1', 'read the plan', 'Reading the plan', 'completed'),
    ('2', 'write the reader', 'Writing the reader', 'completed'),
    ('3', 'render the strip', 'Rendering the strip', 'in_progress'),
    ('4', 'run the suite', 'Running the suite', 'pending'),
    ('10', 'close the phase', 'Closing the phase', 'pending'),
]


def write_todos(tasks, sid, items):
    d = tasks / sid
    d.mkdir(parents=True, exist_ok=True)
    for ident, subject, active, status in items:
        (d / f'{ident}.json').write_text(json.dumps({
            'id': ident, 'subject': subject, 'activeForm': active,
            'status': status, 'blocks': [], 'blockedBy': []}))


def git(repo, *args):
    subprocess.run(['git', '-C', str(repo), *args], check=True,
                   capture_output=True, text=True)


def plan_repo(root, text):
    """A repo whose plan is committed as `wf: plan for <slug>`."""
    repo = root / 'repo'
    plan_dir = repo / '.phased' / 'active' / 'steps'
    plan_dir.mkdir(parents=True)
    (plan_dir / 'plan.md').write_text(text)
    git(repo.parent, 'init', '-q', '-b', 'main', str(repo))
    git(repo, 'config', 'user.email', 'test@example.invalid')
    git(repo, 'config', 'user.name', 'test')
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', 'wf: plan for steps')
    return repo


def stage(life, key):
    return next(g['state'] for g in life if g['key'] == key)


def check_todos():
    with tempfile.TemporaryDirectory() as td:
        tasks = pathlib.Path(td) / 'tasks'
        core.TASKS = tasks
        write_todos(tasks, 'aaaa1111', TODOS)

        t = core.read_todos('aaaa1111')
        assert t['total'] == 5 and t['done'] == 2, t
        # the file names are numbers: 10 comes last, not after 1
        assert [i['id'] for i in t['items']] == ['1', '2', '3', '4', '10'], t['items']
        # what the agent says it is doing, in its own words
        assert t['active_form'] == 'Rendering the strip', t['active_form']

        # a completed step going back to in_progress: the count moves backwards
        back = [(i, s, a, 'in_progress' if i == '2' else st)
                for i, s, a, st in TODOS]
        write_todos(tasks, 'aaaa1111', back)
        t2 = core.read_todos('aaaa1111')
        assert t2['done'] == 1, t2
        assert t2['active_form'] == 'Writing the reader', t2['active_form']

        # no declaration is not zero progress
        assert core.read_todos('bbbb2222') is None
        (tasks / 'cccc3333').mkdir()
        assert core.read_todos('cccc3333') is None
        # a file that is not json is skipped, not fatal
        (tasks / 'cccc3333' / '1.json').write_text('{ broken')
        assert core.read_todos('cccc3333') is None
    print('test_steps: todos ok')


def check_panel():
    """The list on the panel: the wiring from the task directory to the page."""
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        repo = plan_repo(root, RUNNING)
        tasks = root / 'tasks'
        core.TASKS = tasks
        core.PROJECTS = root / 'projects'
        core.live_sessions = lambda: {}
        project = core.PROJECTS / str(repo).replace('/', '-')
        project.mkdir(parents=True)
        for sid in ('aaaa1111', 'bbbb2222'):
            (project / f'{sid}.jsonl').write_text('\n'.join([
                json.dumps({'type': 'custom-title', 'customTitle': f'wf:steps:phase-2 — {sid}'}),
                json.dumps({'type': 'assistant', 'timestamp': '2026-08-26T09:00:00Z',
                            'message': {'model': 'claude-opus-5',
                                        'content': [{'type': 'text', 'text': 'ok'}],
                                        'usage': {'input_tokens': 1, 'output_tokens': 10,
                                                  'cache_read_input_tokens': 100}}})]) + '\n')
        write_todos(tasks, 'aaaa1111', TODOS)

        chats = {c['session_id']: c for c in core.Board(str(repo)).state()['chats']}
        assert chats['aaaa1111']['todos']['done'] == 2
        assert chats['aaaa1111']['todos']['active_form'] == 'Rendering the strip'
        assert chats['bbbb2222']['todos'] is None
    print('test_steps: panel ok')


def check_lifecycle():
    with tempfile.TemporaryDirectory() as td:
        repo = plan_repo(pathlib.Path(td), RUNNING)
        plan = core.read_plan(str(repo))
        # a `> Quality check:` line inside a phase is not the stamp
        assert plan['quality'] is None, plan['quality']
        life = core.lifecycle(str(repo), plan)
        assert [g['key'] for g in life] == ['planned', 'executing', 'quality', 'finalized']
        assert stage(life, 'planned') == 'done' and life[0]['proof']
        assert stage(life, 'executing') == 'now'
        assert stage(life, 'quality') == 'todo'

        # every phase closed: execution is proved, the check is what is due
        (pathlib.Path(plan['dir']) / 'plan.md').write_text(CLOSED)
        plan = core.read_plan(str(repo))
        life = core.lifecycle(str(repo), plan)
        assert stage(life, 'executing') == 'done' and stage(life, 'quality') == 'now'

        # the stamp under its own heading
        (pathlib.Path(plan['dir']) / 'plan.md').write_text(STAMPED)
        plan = core.read_plan(str(repo))
        assert plan['quality'].startswith('2026-08-26T09:00:00Z'), plan['quality']
        life = core.lifecycle(str(repo), plan)
        assert stage(life, 'quality') == 'done' and stage(life, 'finalized') == 'now'

        # the plan really moved under done/, read back the way the page reads it
        done_dir = repo / '.phased' / 'done'
        done_dir.mkdir(parents=True)
        (repo / '.phased' / 'active' / 'steps').rename(done_dir / 'steps')
        assert core.read_plan(str(repo)) is None, 'a finalized plan is not an active one'
        fin = core.finished_plan(str(repo))
        assert fin and fin['slug'] == 'steps', fin
        life = core.lifecycle(str(repo), fin)
        assert [g['state'] for g in life] == ['done'] * 4, life

        # no plan commit: the first stage is the one still due
        bare = pathlib.Path(td) / 'bare'
        bare.mkdir()
        life = core.lifecycle(str(bare), dict(plan, dir=str(bare)))
        assert stage(life, 'planned') == 'now', life
    print('test_steps: lifecycle ok')


def check_finished_on_branch():
    """The case the parent branch is always in after a finalize.

    Finalize SQUASHES the workflow into one commit on the parent and drops
    `.phased/` from it. So on the parent there is no plan directory AND no
    `wf: plan for` commit: both survive only on the `wf/` branch. A strip that
    read the current branch alone showed the first stage as still running on a
    workflow that had finished, and the last stage could never light at all.
    """
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        repo = root / 'repo'
        repo.mkdir()
        git(root, 'init', '-q', '-b', 'main', str(repo))
        git(repo, 'config', 'user.email', 'test@example.invalid')
        git(repo, 'config', 'user.name', 'test')
        (repo / 'README').write_text('before the workflow\n')
        git(repo, 'add', '-A')
        git(repo, 'commit', '-qm', 'chore: the repo before any workflow')

        # the workflow lives on its own branch, plan commit included
        git(repo, 'switch', '-q', '-c', 'wf/steps')
        plan_dir = repo / '.phased' / 'active' / 'steps'
        plan_dir.mkdir(parents=True)
        (plan_dir / 'plan.md').write_text(STAMPED)
        git(repo, 'add', '-A')
        git(repo, 'commit', '-qm', 'wf: plan for steps')
        (repo / 'feature.py').write_text('the work\n')
        git(repo, 'add', '-A')
        git(repo, 'commit', '-qm', 'wf(phase 1): the work')
        done_dir = repo / '.phased' / 'done'
        done_dir.mkdir(parents=True)
        plan_dir.rename(done_dir / 'steps')
        git(repo, 'add', '-A')
        git(repo, 'commit', '-qm', 'wf: archive plan for steps')

        # the parent gets one squashed commit, without .phased/
        git(repo, 'switch', '-q', 'main')
        git(repo, 'merge', '--squash', 'wf/steps')
        git(repo, 'rm', '-r', '-q', '-f', '--cached', '.phased')
        shutil.rmtree(repo / '.phased')
        git(repo, 'commit', '-qm', 'feat: the work, without the scaffolding')

        assert not (repo / '.phased').exists(), 'the parent still carries .phased/'
        subjects = core.git(str(repo), 'log', '--format=%s')
        assert 'wf: plan for' not in subjects, \
            f'the fixture did not squash: the plan commit is still on the parent\n{subjects}'

        assert core.read_plan(str(repo)) is None
        fin = core.finished_plan(str(repo))
        assert fin and fin['slug'] == 'steps', f'the closed plan was not found on its branch: {fin}'
        assert fin['done'] == fin['total'], fin
        life = core.lifecycle(str(repo), fin)
        assert life[0]['proof'], 'the plan commit was not found: it is only on the workflow branch'
        assert [g['state'] for g in life] == ['done'] * 4, life
    print('test_steps: the finalized workflow is found on its branch ok')


def main():
    check_todos()
    check_panel()
    check_lifecycle()
    check_finished_on_branch()
    print('test_steps: ok')


if __name__ == '__main__':
    main()
