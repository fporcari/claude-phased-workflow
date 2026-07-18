#!/usr/bin/env python3
"""Compute the next eligible phase from a MEMORY.md work plan.

Deterministic implementation of the phase-selection semantics used by
the phased-workflow skills (/execute-phase, /auto-phase). The canonical
description of the semantics lives in
~/.claude/workflow-refs/common.md ("Phase selection").

Statuses: [ ] pending, [>] in execution, [x] done, [!] issue, [~] blocked.
Tags (backticked at end of the phase line): parallel:N, group:N, vast.

Rules:
- [x] phases are complete; every other status counts as "not complete".
- A pending phase is blocked while any preceding phase outside its own
  parallel:N group is not complete. A phase without parallel:N is a
  synchronization barrier: all preceding phases must be [x].
- A selected group:N phase pulls in its whole consecutive run of the
  same tag as one unit.
- [>] phases are reported as resume candidates only when no pending
  phase is eligible.

Output: a "phases:" table plus one final "recommendation:" line:
  recommendation: next: 3               execute Phase 3
  recommendation: next: 3 unit: 3,4     group unit, phases run together
  recommendation: resume-candidate: 2 (age: 3.4h, wip: yes)
  recommendation: attention: 5[!]       user must resolve before going on
  recommendation: done                  all phases [x]
  recommendation: blocked: <reason>     pending phases exist, none eligible
"""

import argparse
import re
import subprocess
import sys
from datetime import datetime

PHASE_RE = re.compile(r'^- \[([ x!~>])\] \*\*Phase (\d+)\*\*:\s*(.*)$')
TAG_RE = re.compile(r'`(parallel:\d+|group:\d+|vast)`')
EXEC_RE = re.compile(r'In execution since\s+(\S+)')


class Phase:
    def __init__(self, status, number, rest):
        self.status = status
        self.number = int(number)
        self.tags = TAG_RE.findall(rest)
        self.title = TAG_RE.sub('', rest).strip()
        self.since = None
        self.wip = False

    def _tag(self, prefix):
        for t in self.tags:
            if t.startswith(prefix):
                return t
        return None

    @property
    def parallel(self):
        return self._tag('parallel:')

    @property
    def group(self):
        return self._tag('group:')

    @property
    def age_hours(self):
        if not self.since:
            return None
        try:
            ts = datetime.fromisoformat(self.since.replace('Z', '+00:00'))
        except ValueError:
            return None
        now = datetime.now(ts.tzinfo) if ts.tzinfo else datetime.now()
        return (now - ts).total_seconds() / 3600


def parse(path):
    phases = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = PHASE_RE.match(line.rstrip())
            if m:
                phases.append(Phase(*m.groups()))
            elif phases and line.lstrip().startswith('>'):
                m = EXEC_RE.search(line)
                if m:
                    phases[-1].since = m.group(1)
                if 'WIP:' in line:
                    phases[-1].wip = True
    return phases


def blockers(phases, i):
    """Numbers of preceding phases that block phases[i]."""
    p = phases[i]
    return [q.number for q in phases[:i]
            if q.status != 'x'
            and not (p.parallel and q.parallel == p.parallel)]


def group_unit(phases, i):
    """Numbers of the maximal consecutive run sharing phases[i]'s group tag."""
    tag = phases[i].group
    if not tag:
        return None
    lo = i
    while lo > 0 and phases[lo - 1].group == tag:
        lo -= 1
    hi = i
    while hi + 1 < len(phases) and phases[hi + 1].group == tag:
        hi += 1
    return [p.number for p in phases[lo:hi + 1]]


def default_memory_path():
    try:
        root = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, OSError):
        root = '.'
    return f'{root}/.claude/MEMORY.md'


def describe(phases, i):
    p = phases[i]
    parts = [f'  {p.number} [{p.status}] {p.title}']
    if p.tags:
        parts.append(' '.join(f'`{t}`' for t in p.tags))
    if p.status == '>':
        age = p.age_hours
        age_s = f'{age:.1f}h' if age is not None else 'unknown'
        parts.append(f'(since: {p.since or "?"}, age: {age_s}, '
                     f'wip: {"yes" if p.wip else "no"})')
    if p.status == ' ':
        blocked_by = blockers(phases, i)
        parts.append(f'[blocked by: {",".join(map(str, blocked_by))}]'
                     if blocked_by else '[eligible]')
    return ' '.join(parts)


def recommend(phases):
    for i, p in enumerate(phases):
        if p.status == ' ' and not blockers(phases, i):
            unit = group_unit(phases, i)
            if unit and len(unit) > 1:
                return f'next: {p.number} unit: {",".join(map(str, unit))}'
            return f'next: {p.number}'
    candidates = [p for p in phases if p.status == '>']
    if candidates:
        p = candidates[0]
        age = p.age_hours
        age_s = f'{age:.1f}h' if age is not None else 'unknown'
        return (f'resume-candidate: {p.number} '
                f'(age: {age_s}, wip: {"yes" if p.wip else "no"})')
    stuck = [p for p in phases if p.status in '!~']
    if stuck and any(p.status == ' ' for p in phases):
        nums = ' '.join(f'{p.number}[{p.status}]' for p in stuck)
        return f'attention: {nums}'
    if all(p.status == 'x' for p in phases):
        return 'done'
    if stuck:
        nums = ' '.join(f'{p.number}[{p.status}]' for p in stuck)
        return f'attention: {nums}'
    return 'blocked: pending phases exist but none is eligible'


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('memory', nargs='?', default=None,
                    help='path to MEMORY.md '
                         '(default: <git root>/.claude/MEMORY.md)')
    args = ap.parse_args()
    path = args.memory or default_memory_path()
    try:
        phases = parse(path)
    except OSError as e:
        print(f'error: cannot read {path}: {e}')
        return 1
    if not phases:
        print(f'error: no phases found in {path}')
        return 1
    print('phases:')
    for i in range(len(phases)):
        print(describe(phases, i))
    print(f'recommendation: {recommend(phases)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
