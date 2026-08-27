#!/usr/bin/env python3
"""wfdash roadmap: icon derivation and the tree from roadmap.md.

Two things are asserted, both against fixtures on disk:

  - the icon of a phase comes from its marker and its notes, and from
    nothing else: a closed phase carrying a `> Review:` is not a plain
    closed one, and a `[>]` phase awaiting the human's checks is not a
    plain running one;
  - a roadmap.md parses into its macro-phases, each one taking its state
    from WHERE its plan directory sits — `done/` closed, `active/` in
    progress, neither one not started;
  - a plan that lives only on its own `wf/` branch — the shape finalize
    leaves behind — is found there, so a macro-phase closed long ago does
    not read as one nobody ever started.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core       # noqa: E402
import roadmap    # noqa: E402

MARKERS = """# Context: wf/macro2-something
Mode: interactive

## Work Plan
- [x] **Phase 1**: closed clean
  - Run: opus / medium
- [x] **Phase 2**: closed carrying a judgment
  > Review: the header carries a clock absent from the mockup
  - Run: opus / medium
- [!] **Phase 3**: failed
  > Issue: the suite stays red
  - Run: opus / high
- [~] **Phase 4**: blocked
  > Blocked: a red baseline nobody owns
  - Run: opus / medium
- [>] **Phase 5**: running
  > In execution since 2026-08-25T09:00:00+02:00
  - Run: opus / medium
- [>] **Phase 6**: awaiting the human
  > Testing: awaiting the human's `Verify: now` checks | commit: abc1234
  - Run: opus / medium
- [ ] **Phase 7**: not started yet
  - Run: opus / medium
  - Verify: now — read one line per stack and check the caller is the SITE
    code you expect, not the recorder
"""

ROADMAP = """# Roadmap — the bench

## Macro-phase 1 — Data collection

- Mini-scope: the two recorders
- Ends at: both stacks recorded

## Macro-phase 2 — The replica

- Mini-scope: the replica; the structural comparison
- Ends at: the reference session replicated with no divergence

## Macro-phase 3 — Performance

- Mini-scope: the memory sampler
- Ends at: a report comparing the two stacks

## Must not break (in transit across the macro-phases)

- No format versioning: the traces are consumed immediately.
"""


def build(tmp):
    repo = tmp / 'repo'
    (repo / '.phased').mkdir(parents=True)
    (repo / '.phased' / 'roadmap.md').write_text(ROADMAP)
    done = repo / '.phased' / 'done' / 'macro1-legacy-collection'
    done.mkdir(parents=True)
    (done / 'plan.md').write_text('# Context: wf/macro1-legacy-collection\n\n'
                                  '## Work Plan\n- [x] **Phase 1**: recorded\n')
    active = repo / '.phased' / 'active' / 'macro2-something'
    active.mkdir(parents=True)
    (active / 'plan.md').write_text(MARKERS)
    return repo


MACRO1 = ('# Context: wf/macro1-legacy-collection\n\n## Work Plan\n'
          '- [x] **Phase 1**: the two recorders\n'
          '  > Done: both stacks recorded\n'
          '  > Files: recorder.py, interceptor.py\n')


def git(repo, *args):
    subprocess.run(['git', '-C', str(repo), *args], check=True,
                   capture_output=True, text=True)


def branch_repo(root):
    """A repo where macro1's plan exists ONLY on its own branch.

    It is the shape /wf:finalize-workflow leaves behind: `.phased/` does not
    enter the squash that reaches the parent, so `done/` survives where it was
    born.
    """
    repo = root / 'gitrepo'
    (repo / '.phased').mkdir(parents=True)
    git(repo.parent, 'init', '-q', '-b', 'main', str(repo))
    git(repo, 'config', 'user.email', 'test@example.invalid')
    git(repo, 'config', 'user.name', 'test')
    (repo / '.phased' / 'roadmap.md').write_text(ROADMAP)
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', 'roadmap')
    git(repo, 'switch', '-qc', 'wf/macro1-legacy-collection')
    done = repo / '.phased' / 'done' / 'macro1-legacy-collection'
    done.mkdir(parents=True)
    (done / 'plan.md').write_text(MACRO1)
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', 'wf: plan for macro1-legacy-collection')
    git(repo, 'switch', '-q', 'main')
    return repo


def check_branch_plans():
    with tempfile.TemporaryDirectory() as td:
        repo = branch_repo(pathlib.Path(td))
        # no plan in the working tree: only the roadmap
        assert core.all_plan_dirs(repo) == [], core.all_plan_dirs(repo)
        found = core.branch_plan_dirs(repo)
        assert [(f['slug'], f['state'], f['branch']) for f in found] == [
            ('macro1-legacy-collection', 'done', 'wf/macro1-legacy-collection')], found

        tree = core.Board(str(repo)).tree(None, [])
        m1 = tree['nodes'][0]
        assert m1['n'] == 1 and m1['state'] == 'done' and m1['icon'] == '✓', m1
        assert m1['branch'] == 'wf/macro1-legacy-collection'
        assert [p['n'] for p in m1['phases']] == [1]
        # the notes travel: reviewing closed work is reading them
        kinds = {n['kind'] for n in m1['phases'][0]['notes']}
        assert kinds == {'Done', 'Files'}, kinds
        # a macro-phase with no plan anywhere stays not started
        assert [n['state'] for n in tree['nodes']] == ['done', 'none', 'none']

        # a second read does not hit git again: the tips have not moved
        board = core.Board(str(repo))
        board.plans_on_branches()
        tips = board.branch_tips
        board.plans_on_branches()
        assert board.branch_tips is tips
    print('test_roadmap: branch plans ok')


def main():
    check_branch_plans()
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td)
        repo = build(tmp)

        # -- the icons, from marker plus notes -----------------------------
        _, phases, _ = core.parse_plan(repo / '.phased' / 'active' /
                                       'macro2-something' / 'plan.md')
        icons = {p['n']: roadmap.phase_icon(p) for p in phases}
        assert icons[1]['icon'] == '✓' and icons[1]['cls'] == 'x', icons[1]
        assert icons[2]['icon'] == '✓!', icons[2]      # closed, carries a Review
        assert icons[3]['icon'] == '✕' and icons[3]['cls'] == 'e', icons[3]
        assert icons[4]['icon'] == '⊘', icons[4]
        assert icons[5]['icon'] == '◐' and icons[5]['cls'] == 'r', icons[5]
        assert icons[6]['icon'] == '👤', icons[6]      # [>] awaiting the human
        assert icons[7]['icon'] == '○', icons[7]
        assert not any(i['warn'] for i in icons.values())

        # the warning rides on an ACTIVE agent with API errors, nothing else
        quiet = [{'errors': 3, 'active': False}, {'errors': 0, 'active': True}]
        assert not roadmap.phase_icon(phases[0], quiet)['warn']
        assert roadmap.phase_icon(phases[0], [{'errors': 1, 'active': True}])['warn']

        # a Verify: field wrapped over two lines is ONE step, joined
        assert phases[6]['verify'] == [{'text': 'now — read one line per stack and '
                                        'check the caller is the SITE code you '
                                        'expect, not the recorder'}], phases[6]['verify']

        # -- the roadmap, and the state of each macro-phase ----------------
        rm = roadmap.read_roadmap(repo)
        assert rm['title'] == 'Roadmap — the bench', rm['title']
        assert [m['n'] for m in rm['macros']] == [1, 2, 3], rm['macros']
        assert rm['macros'][1]['title'] == 'The replica'
        assert rm['macros'][0]['mini_scope'] == 'the two recorders'
        assert rm['macros'][2]['ends_at'] == 'a report comparing the two stacks'

        plans = []
        for entry in core.all_plan_dirs(repo):
            _, ph, _ = core.parse_plan(pathlib.Path(entry['dir']) / 'plan.md')
            plans.append(dict(entry, phases=ph))
        tree = roadmap.build_tree(rm, plans, 'macro2-something')
        assert tree['roadmap'] is True
        states = [(n['n'], n['state'], n['icon']) for n in tree['nodes']]
        assert states == [(1, 'done', '✓'), (2, 'active', '◐'), (3, 'none', '○')], states
        assert tree['nodes'][1]['slug'] == 'macro2-something'
        assert len(tree['nodes'][1]['phases']) == 7
        assert all(p['mine'] for p in tree['nodes'][1]['phases'])
        # a phase of the closed macro-phase belongs to another plan
        assert tree['nodes'][0]['phases'][0]['mine'] is False

        # -- no roadmap.md: the active plan is the root, as before ---------
        (repo / '.phased' / 'roadmap.md').unlink()
        flat = roadmap.build_tree(roadmap.read_roadmap(repo), plans, 'macro2-something')
        assert flat['roadmap'] is False
        assert flat['label'] == 'macro2-something'
        assert [p['n'] for p in flat['phases']] == [1, 2, 3, 4, 5, 6, 7]
    print('test_roadmap: ok')


if __name__ == '__main__':
    main()
