#!/usr/bin/env python3
"""The tag survives the whole road, and the button labels match the docs.

Two defects a browser pass found after every phase had closed green, both of
them invisible to the tests that existed.

**The tag never reached the grid.** The phase payload carries `tags`, the page
knows how to render them, and the rows the grid is built from come from a
DIFFERENT projection — one that names its fields one by one and did not name
`tags`. So the chip renderer was always handed `undefined` and always returned
nothing. The page-side test could not see it: asserting that the page READS a
field says nothing about the field ARRIVING. This one asserts the road, from
the plan text to the row the grid renders.

**The fourth button label did not match its documentation.** `docs/wfdash.md`
promised a *create workflow* button; the page says `Create`. Three of the four
matched exactly, which is how the fourth went unnoticed for two releases —
the check existed, on a verify list nobody had ever run.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'))
import core  # noqa: E402
import roadmap  # noqa: E402

PLAN = """# Context: wf/toy
Parent: main
Mode: autonomous

## Work Plan
- [x] **Phase 1**: the closed one
  - Done: nothing
- [ ] **Phase 2**: the open one  `vast`
  - Done: nothing
"""

repo = pathlib.Path(tempfile.mkdtemp(prefix='wfdash-tags-'))
(repo / '.phased' / 'active' / 'toy').mkdir(parents=True)
(repo / '.phased' / 'active' / 'toy' / 'plan.md').write_text(PLAN)

# --- the reader sees the tag ---------------------------------------------

plan = core.read_plan(repo)
assert plan is not None, 'the reader refused the fixture plan'
tagged = {p['n']: p.get('tags') for p in plan['phases']}
assert tagged == {1: [], 2: ['vast']}, \
    f'the payload lost the tag before the grid was even built: {tagged}'
print('test_tags_reach_the_grid: the payload carries the tag ok')

# --- and so does the projection the GRID is built from -------------------

rows = roadmap._phases(plan, plan['slug'])
carried = {r['n']: r.get('tags') for r in rows}
assert carried == {1: [], 2: ['vast']}, \
    ('the grid rows dropped the tag: the page renders chips from THIS '
     f'projection, so a tag missing here is a tag nobody ever sees — {carried}')
print('test_tags_reach_the_grid: the grid rows carry the tag ok')

# --- the page renders from the field the projection provides -------------

PAGE = (ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash' / 'index.html').read_text()
assert 'tagChips' in PAGE and '.tags' in PAGE, \
    'the page no longer renders the tags the projection now carries'
print('test_tags_reach_the_grid: the page renders that field ok')

# --- every documented button label is a label the page actually shows ----

DOCS = (ROOT / 'docs' / 'wfdash.md').read_text()
for label in ('Ask for an unattended run', 'Command for phase', 'queue', 'Create'):
    assert label in PAGE, f'the page has no {label!r} button'
    assert label in DOCS, \
        (f'docs/wfdash.md never names the {label!r} button the page shows — '
         'the button table and the page must agree')
print('test_tags_reach_the_grid: the documented labels are the real ones ok')

print('test_tags_reach_the_grid ok')
