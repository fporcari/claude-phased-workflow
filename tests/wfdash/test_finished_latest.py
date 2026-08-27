#!/usr/bin/env python3
"""`finished_plan` returns the workflow finalized LAST, on branches too.

The defect this pins, reproduced before the fix: with no plan directory on
disk — the state every parent branch is in after a finalize — the branch leg
of `finished_plan` returned the FIRST `done` plan the ref listing named, and
`for-each-ref` sorts by refname. Two closed workflows, and the page's
lifecycle strip showed whichever slug sorted first, not what had just been
built. The on-disk leg already ordered by mtime; the branch leg ordered by
nothing.

The fixture puts the OLDER finalized plan on the branch that sorts first, so
the unordered walk cannot pass by luck.

Two things are asserted:

  - with two `done/` plans on two branches, the one whose finalizing commit is
    most recent wins, against the ref order;
  - a lone finalized plan is still found (the ordering did not break the
    single-branch case).

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import os
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402

PLAN = '- [x] **Phase 1**: the work\n'


def git(repo, *args, date=None):
    env = dict(os.environ)
    if date:
        env.update(GIT_COMMITTER_DATE=date, GIT_AUTHOR_DATE=date)
    subprocess.run(['git', '-C', str(repo), *args], check=True, env=env,
                   capture_output=True, text=True)


def finalize_on_branch(repo, branch, slug, date):
    """A closed workflow the way finalize leaves it: only on its own branch."""
    git(repo, 'switch', '-q', 'main')
    git(repo, 'switch', '-q', '-c', branch)
    plan_dir = repo / '.phased' / 'done' / slug
    plan_dir.mkdir(parents=True)
    (plan_dir / 'plan.md').write_text(PLAN)
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', f'wf: archive plan for {slug}', date=date)
    git(repo, 'switch', '-q', 'main')
    subprocess.run(['rm', '-rf', str(repo / '.phased')], check=True)


with tempfile.TemporaryDirectory() as td:
    repo = pathlib.Path(td) / 'repo'
    repo.mkdir()
    git(repo.parent, 'init', '-q', '-b', 'main', str(repo))
    git(repo, 'config', 'user.email', 'test@example.invalid')
    git(repo, 'config', 'user.name', 'test')
    (repo / 'README').write_text('before any workflow\n')
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', 'chore: the repo before any workflow')

    # The older plan on the branch that sorts FIRST: the unordered walk
    # returned this one.
    finalize_on_branch(repo, 'wf/a-old', 'older', '2026-01-01T10:00:00')

    fin = core.finished_plan(str(repo))
    assert fin and fin['slug'] == 'older', f'the lone finalized plan was not found: {fin}'
    print('test_finished_latest: a lone finalized plan is still found ok')

    finalize_on_branch(repo, 'wf/b-new', 'newer', '2026-02-01T10:00:00')

    fin = core.finished_plan(str(repo))
    assert fin, 'no finished plan found with two done/ branches'
    assert fin['slug'] == 'newer', \
        f"the ref order won over the finalize date: {fin['slug']}"
    print('test_finished_latest: the last finalized workflow wins ok')

print('test_finished_latest ok')
