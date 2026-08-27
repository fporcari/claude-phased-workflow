#!/usr/bin/env python3
"""Phase 9 contract: the README says what the repository actually is.

Three claims a visitor reads first, and nothing checked any of them.

**The changelog table skips versions.** `CHANGELOG.md` carries 6.24.0 and the
README's table does not, and no assert noticed: S42 couples the shipped version
to the README's headline and to the CHANGELOG's first heading, never the table's
continuity. The table is a WINDOW, not the whole history, so the rule is a
window rule — inside the range it covers, from its highest row to its lowest,
no version may be missing.

**The suite's own numbers.** "N assertions over M scenarios" was measured once
and left to rot. That is not a cosmetic defect: the graft's Phase 6 wrote a note
claiming the suite topped out at S33 because it trusted a stale README instead
of `run_tests.sh`, and the same habit put eight defects in that plan. The number
this guard pins is the STATIC one — the `assert "` call sites in the file — not a
run's `RESULT:` line, which S51's loop over the wfdash tests makes depend on how
many test files happen to exist.

**`-P`'s justification.** Both `server.py` and the wfdash documentation explain
why an explicit port never scans by appealing to a `.claude/launch.json` that
declares the port — a file this repository does not ship, and that
`skills/dashboard/SKILL.md` never passes `-P` for. A justification resting on a
file nobody ships is worse than none: the next reader looks for it.

Usage: check_readme_continuity.py <repo root>   (default: two levels up,
which is the repository root once this file sits in `tests/orchestration/`)
Exit 0 clean, 1 with one violation per line on stdout — the S21/S18 guard idiom,
so the scenario can re-run the REAL check on a mutated copy.
"""
import pathlib
import re
import sys

CHANGELOG_HEAD = re.compile(r'^## (\d+\.\d+\.\d+)\b')
TABLE_ROW = re.compile(r'^\| (\d+\.\d+\.\d+) \|')
CLAIM = re.compile(r'\*\*(\d+) assertions over (\d+) scenarios\*\*\s*'
                   r'\(S1[–-]S(\d+)')
SCENARIO = re.compile(r'^echo "== S(\d+)')
ASSERT_SITE = re.compile(r'assert "')


def version(text):
    return tuple(int(p) for p in text.split('.'))


def table_window(readme_lines):
    """Every version the README's changelog table carries, newest first."""
    return [m.group(1) for m in
            (TABLE_ROW.match(ln) for ln in readme_lines) if m]


def continuity(root, bad):
    changelog = (root / 'CHANGELOG.md').read_text().splitlines()
    readme = (root / 'README.md').read_text().splitlines()
    shipped = [m.group(1) for m in
               (CHANGELOG_HEAD.match(ln) for ln in changelog) if m]
    listed = table_window(readme)
    if not listed:
        bad.append('README.md: no changelog table rows found')
        return
    top, bottom = version(listed[0]), version(listed[-1])
    for v in shipped:
        if bottom <= version(v) <= top and v not in listed:
            bad.append(f'README.md: the changelog table skips {v}, which '
                       f'CHANGELOG.md carries')


def suite_numbers(root, bad):
    runner = (root / 'tests' / 'orchestration' / 'run_tests.sh').read_text()
    lines = runner.splitlines()
    scenarios = {int(m.group(1)) for m in
                 (SCENARIO.match(ln) for ln in lines) if m}
    sites = sum(1 for ln in lines if ASSERT_SITE.search(ln))
    readme = (root / 'README.md').read_text()
    m = CLAIM.search(readme)
    if not m:
        bad.append('README.md: the "N assertions over M scenarios (S1-SX)" '
                   'claim is gone — the guard has nothing to check')
        return
    claimed_asserts, claimed_scenarios, claimed_top = (int(g) for g in m.groups())
    if claimed_asserts != sites:
        bad.append(f'README.md: claims {claimed_asserts} assertions, '
                   f'run_tests.sh has {sites}')
    if claimed_scenarios != len(scenarios):
        bad.append(f'README.md: claims {claimed_scenarios} scenarios, '
                   f'run_tests.sh has {len(scenarios)}')
    if claimed_top != max(scenarios):
        bad.append(f'README.md: claims the suite tops out at S{claimed_top}, '
                   f'run_tests.sh reaches S{max(scenarios)}')


def launch_json(root, bad):
    if (root / '.claude' / 'launch.json').is_file():
        return
    for rel in ('plugins/wf/scripts/wfdash/server.py',
                'docs/wfdash.md',
                'plugins/wf/skills/dashboard/SKILL.md'):
        f = root / rel
        if f.is_file() and 'launch.json' in f.read_text():
            bad.append(f'{rel}: justifies -P by a .claude/launch.json this '
                       f'repository does not ship')


if __name__ == '__main__':
    where = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else \
        pathlib.Path(__file__).resolve().parents[2]
    found = []
    continuity(where, found)
    suite_numbers(where, found)
    launch_json(where, found)
    if found:
        print('\n'.join(found))
    sys.exit(1 if found else 0)
