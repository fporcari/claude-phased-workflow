#!/usr/bin/env python3
"""The Done tab: which rows are archive, and which are still the plan.

Issue #18 — on a repository with a long history the plan list showed the
active workflow followed by every finalized one, and the archive drowned the
one plan being worked. The rule chosen for what moves out is the reporter's
own: a macro-phase whose parent is gone loses its meaning, so the plans of
past roadmaps are archive; the macro-phases the CURRENT roadmap declares stay
in the plan even when closed, because that sequence IS the roadmap.

Three things are asserted:

  - a finalized workflow no macro-phase declares is archive;
  - a macro-phase of the current roadmap is NOT archive when it closes;
  - an orphan plan still being worked is NOT archive — the tab takes what is
    finished, not what has no parent.

Plus the page: it carries the tab and partitions on the same predicate.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]
                       / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core       # noqa: E402
import roadmap    # noqa: E402

ROADMAP = """# Roadmap — the current project

## Macro-phase 1 — Collection

- Mini-scope: the recorders
- Ends at: both stacks recorded

## Macro-phase 2 — The replica

- Mini-scope: the replica
- Ends at: replicated with no divergence
"""


def plan(directory, closed=True):
    directory.mkdir(parents=True)
    mark = 'x' if closed else ' '
    (directory / 'plan.md').write_text(
        f'# Context: wf/{directory.name}\nMode: interactive\n\n'
        f'## Work Plan\n- [{mark}] **Phase 1**: something\n  - Run: opus / medium\n')


def build(tmp):
    repo = tmp / 'repo'
    (repo / '.phased').mkdir(parents=True)
    (repo / '.phased' / 'roadmap.md').write_text(ROADMAP)
    # Macro-phase 1 of the current roadmap, closed: it stays in the plan.
    plan(repo / '.phased' / 'done' / 'macro1-collection')
    # Macro-phase 2 of the current roadmap, in progress.
    plan(repo / '.phased' / 'active' / 'macro2-replica', closed=False)
    # Three workflows of past roadmaps, finished: the archive.
    for name in ('old-parser', 'old-transport', 'old-ui'):
        plan(repo / '.phased' / 'done' / name)
    return repo


def tree_of(repo):
    plans = []
    for entry in core.all_plan_dirs(str(repo)):
        sel = core.selection(path=pathlib.Path(entry['dir']) / 'plan.md')
        plans.append(dict(entry, phases=sel['phases'] if sel else []))
    return roadmap.build_tree(roadmap.read_roadmap(str(repo)), plans,
                              'macro2-replica')


def archived(node):
    """The page's own predicate, in Python. Kept in step by the check below."""
    return node['kind'] == 'plan' and node['state'] == 'done'


with tempfile.TemporaryDirectory() as tmp:
    tree = tree_of(build(pathlib.Path(tmp)))
    arch = {n['slug'] for n in tree['nodes'] if archived(n)}
    kept = {n['slug'] for n in tree['nodes'] if not archived(n)}

    assert arch == {'old-parser', 'old-transport', 'old-ui'}, \
        f'the archive is not the finalized workflows of past roadmaps: {arch}'
    print('test_done_tab: a finalized workflow no roadmap declares is archive ok')

    assert 'macro1-collection' in kept, \
        ('a closed macro-phase of the current roadmap left the plan: the '
         'sequence of the closed ones is what the roadmap shows')
    print('test_done_tab: a closed macro-phase of the roadmap stays in the plan ok')

    assert 'macro2-replica' in kept, \
        'the workflow being worked was filed as archive'
    print('test_done_tab: the active plan stays in the plan ok')

# --- the page ---------------------------------------------------------------

PAGE = (pathlib.Path(__file__).resolve().parents[2] / 'plugins' / 'wf'
        / 'scripts' / 'wfdash' / 'index.html').read_text()

assert "'done','Done'" in PAGE, \
    'the page has no Done tab: the archive still rides in the plan list'
assert "n.kind==='plan'&&n.state==='done'" in PAGE, \
    ('the page partitions on some other rule than this test pins: the two '
     'must move together')
assert "archived(n)===arch" in PAGE, \
    'the grid does not split its rows on the archive predicate'
print('test_done_tab: the page carries the tab and the same predicate ok')

print('test_done_tab ok')
