#!/usr/bin/env python3
"""The plan's own words on the page are the ones on disk.

The pane under a phase reads `/api/plantext` once per `<slug>:<phase>` key and
keeps the answer for as long as the page is open — the file changes rarely and
re-reading it every five seconds would fight the reader. Rarely is not never:
a plan rewritten while the pane was open went on showing the words it had been
opened with, beside a row the tick had already moved to the new ones. Reported
from the field, on a plan whose phases had just been rewritten.

The fix is a stamp, not a poll: `state()` carries the mtime of every plan text
the page can show, and a cached copy cut from a different one is re-read.

Four things are asserted:

  - `text_stamps` names every plan on disk and the roadmap, by mtime;
  - a rewritten plan.md moves its own stamp and no other;
  - `Board.state()` publishes the stamps, so they ride the tick the page
    already makes;
  - the page compares the stamp before serving a cached text, and both its
    readers go through the one loader that does.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import os
import pathlib
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
WFDASH = ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash'
sys.path.insert(0, str(WFDASH))
import core  # noqa: E402

PAGE = (WFDASH / 'index.html').read_text()

PLAN = """# Context: wf/myplan
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: one
  - Done: a
"""


def build(tmp):
    repo = tmp / 'repo'
    (repo / '.phased').mkdir(parents=True)
    (repo / '.phased' / 'roadmap.md').write_text('# Roadmap\n\n## Macro-phase 1 — one\n')
    for state, slug in (('active', 'myplan'), ('done', 'oldplan')):
        d = repo / '.phased' / state / slug
        d.mkdir(parents=True)
        (d / 'plan.md').write_text(PLAN)
    return repo


def main():
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td)
        repo = build(tmp)

        # --- every plan on disk and the roadmap are named -----------------

        stamps = core.text_stamps(str(repo))
        assert sorted(stamps['plans']) == ['myplan', 'oldplan'], stamps['plans']
        assert stamps['roadmap'] is not None, 'the roadmap carries no stamp'
        for slug, mtime in stamps['plans'].items():
            on_disk = (repo / '.phased'
                       / ('active' if slug == 'myplan' else 'done')
                       / slug / 'plan.md').stat().st_mtime
            assert mtime == on_disk, f'{slug}: {mtime} is not the file mtime {on_disk}'
        print('test_plan_text_freshness: every plan text is stamped by mtime ok')

        # --- a rewrite moves that plan's stamp, and only that one ---------

        active = repo / '.phased' / 'active' / 'myplan' / 'plan.md'
        active.write_text(PLAN.replace('one', 'ONE REWRITTEN'))
        # Explicit rather than trusting the clock: two writes inside one mtime
        # tick would make this pass for the wrong reason on a coarse filesystem.
        os.utime(active, (stamps['plans']['myplan'] + 10,) * 2)
        after = core.text_stamps(str(repo))
        assert after['plans']['myplan'] != stamps['plans']['myplan'], \
            'a rewritten plan.md kept its stamp: the page would keep the old words'
        assert after['plans']['oldplan'] == stamps['plans']['oldplan'], \
            'an untouched plan lost its stamp: every other pane would re-read for nothing'
        assert after['roadmap'] == stamps['roadmap'], 'the roadmap stamp moved on its own'
        print('test_plan_text_freshness: a rewrite moves its own stamp ok')

        # --- the stamps ride the tick -------------------------------------

        core.PROJECTS = tmp / 'projects'
        core.live_sessions = lambda: {}
        state = core.Board(str(repo)).state()
        assert 'stamps' in state, 'the tick carries no stamps: the page cannot tell'
        assert state['stamps']['plans']['myplan'] == after['plans']['myplan'], \
            state['stamps']
        # A repo with no `.phased/` answers rather than raising.
        assert core.Board(td).state()['stamps'] == {'plans': {}, 'roadmap': None}
        print('test_plan_text_freshness: the stamps ride the tick ok')

    # --- the page compares the stamp before serving a cached text ---------

    assert 'if(planText[key]!==undefined)return;' not in PAGE, \
        ('the page still serves a cached plan text unconditionally: '
         'a rewritten plan stays on screen until the page is reloaded')
    assert 'planStamp[key]===stamp' in PAGE, \
        'the loader does not compare the cached copy against the tick\'s stamp'
    for reader in ('loadRoadmap', 'loadPlanText'):
        body = PAGE.split(f'async function {reader}(', 1)[1].split('\n}', 1)[0]
        assert 'loadText(' in body, \
            f'{reader} does not go through loadText: it can cache without a stamp'
    print('test_plan_text_freshness: the page re-reads a text whose stamp moved ok')

    print('test_plan_text_freshness ok')


if __name__ == '__main__':
    main()
