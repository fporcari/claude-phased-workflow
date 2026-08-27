#!/usr/bin/env python3
"""Phase 7 contract: what the payload knows reaches the page.

Two things the state payload carries and the page dropped:

  - the phase TAGS. They used to ride inside the title, backticked, while the
    dashboard parsed plan.md itself. The single reader moved them into their own
    `tags` field and nothing picked them up, so a `vast` or `ui` phase now looks
    like any other on screen;
  - the RECOMMENDATION. `--json` restored the five-outcome distinction —
    `next: N`, `resume-candidate: N`, `attention: ...`, `done`, `blocked: ...` —
    and the page still builds its sentence from `blocked_by` alone, so four of
    the five outcomes never reach a person.

Asserted against `index.html` itself: this is a rendering phase, nothing is
fetched that was not already fetched, and the page is the artifact. The two
witnesses are chosen because neither string can be in the file by accident —
today the file contains neither.

Three things are asserted:

  - the page reads the payload's `tags`;
  - the page reads `recommendation`;
  - the two outcomes that only the recommendation can express are named in it,
    so the sentence is a five-way read and not the old two-way one.

Bare asserts, no framework: exit 0 clean, raises on the first failure.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAGE = (ROOT / 'plugins' / 'wf' / 'scripts' / 'wfdash' / 'index.html').read_text()

# --- the page reads the tags ----------------------------------------------

assert re.search(r'\.tags\b', PAGE), \
    'the page never reads the payload\'s tags: a vast or ui phase renders bare'
print('test_page_render: the page reads the phase tags ok')

# --- the page reads the recommendation ------------------------------------

assert 'recommendation' in PAGE, \
    'the page never reads recommendation: four of the five outcomes are invisible'
print('test_page_render: the page reads the recommendation ok')

# --- the outcomes only the recommendation can express are named -----------

for outcome in ('resume-candidate', 'attention'):
    assert outcome in PAGE, \
        (f'the page names no {outcome!r} outcome: the sentence is still the '
         'two-way one built from blocked_by')
print('test_page_render: the five-outcome distinction reaches the page ok')

print('test_page_render ok')
