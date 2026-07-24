#!/usr/bin/env python3
"""Desk analysis of the archived benchmark runs — free, no sessions.

Why this exists
---------------
Before booking a paid benchmark night, the cheapest useful question is: how
noisy is each endpoint already? The per-arm coefficient of variation sizes
every arm of any future design, and it is sitting in the archived
`result.json` files for nothing.

It also cross-checks the JSON's own `duration_ms` against the wall clock the
harness recorded in `results.csv`. They are not always the same number, and
where they disagree the turn count is not measuring the session either.

Usage: tools/bench-stats.py [results-dir]
"""
import csv
import json
import pathlib
import re
import statistics
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    pathlib.Path(__file__).resolve().parent.parent / 'tests/benchmark/results')


def wall_clock():
    """(arm, run) -> duration_s as the harness measured it, from results.csv."""
    out = {}
    for csv_path in ROOT.rglob('results.csv'):
        with csv_path.open() as fh:
            for row in csv.DictReader(fh):
                label = row['config'].split('-', 1)[-1]
                out[(csv_path.parent.name, label, row['run'])] = float(row['duration_s'])
    return out


def cv(xs):
    xs = [x for x in xs if isinstance(x, (int, float))]
    if len(xs) < 2:
        return None
    mean = statistics.mean(xs)
    return statistics.stdev(xs) / mean if mean else None


def pct(v):
    return f'{v:.1%}' if v is not None else 'n/a'


def main():
    walls = wall_clock()
    rows = []
    for f in sorted(ROOT.rglob('*result.json')):
        d = json.loads(f.read_text())
        stem = f.name.replace('.result.json', '').replace('result.json', 'single')
        m = re.match(r'(?P<model>[a-z]+)-(?P<arm>[a-z0-9]+)-(?P<run>\d+)$', stem)
        usage = d.get('usage', {})
        rows.append(dict(
            run_dir=f.parent.name,
            arm=m.group('arm') if m else stem,
            model=m.group('model') if m else '?',
            idx=m.group('run') if m else '1',
            turns=d.get('num_turns'),
            cost=d.get('total_cost_usd') or 0.0,
            json_s=round((d.get('duration_ms') or 0) / 1000),
            out_tok=usage.get('output_tokens') or 0,
            cache_read=usage.get('cache_read_input_tokens') or 0,
            models='+'.join(sorted(k.split('-')[1] for k in d.get('modelUsage', {}))),
        ))

    print(f'{len(rows)} archived runs in {ROOT}\n')
    head = (f"{'run':<40} {'arm':<9} {'turns':>5} {'cost$':>7} {'json_s':>7} "
            f"{'wall_s':>7} {'out_tok':>8} {'models':<13}")
    print(head)
    print('-' * len(head))
    suspect = []
    for r in rows:
        wall = walls.get((r['run_dir'], r['arm'], r['idx']))
        flag = ''
        if wall and r['json_s'] and (wall / r['json_s'] > 2 or r['json_s'] / wall > 2):
            flag = '  <-- json/wall disagree'
            suspect.append(r)
        print(f"{r['run_dir']:<40} {r['arm']:<9} {r['turns']:>5} {r['cost']:>7.3f} "
              f"{r['json_s']:>7} {(f'{wall:.0f}' if wall else '-'):>7} {r['out_tok']:>8} "
              f"{r['models']:<13}{flag}")

    arms = {}
    for r in rows:
        arms.setdefault(r['arm'], []).append(r)

    print('\nPer-arm dispersion — what sizes a future experiment\n')
    print(f"{'arm':<10} {'n':>2} {'cost_mean':>10} {'cost_CV':>8} {'turns_mean':>11} "
          f"{'turns_CV':>9} {'out_CV':>7}")
    for arm, rs in sorted(arms.items()):
        print(f"{arm:<10} {len(rs):>2} {statistics.mean([r['cost'] for r in rs]):>10.3f} "
              f"{pct(cv([r['cost'] for r in rs])):>8} "
              f"{statistics.mean([r['turns'] for r in rs]):>11.1f} "
              f"{pct(cv([r['turns'] for r in rs])):>9} "
              f"{pct(cv([r['out_tok'] for r in rs])):>7}")

    print('\nRuns needed per arm to resolve a 30% cost gap at ~80% power (rough two-sample t):')
    for arm, rs in sorted(arms.items()):
        c = cv([r['cost'] for r in rs])
        if c:
            print(f'  {arm:<10} cost CV {c:.1%}  ->  n ~= {2 * 2.8 ** 2 * c ** 2 / 0.30 ** 2:.0f}')

    if suspect:
        print(f'\n{len(suspect)} run(s) where the JSON duration and the harness wall clock '
              f'disagree by more than 2x:')
        for r in suspect:
            print(f"  {r['run_dir']}/{r['arm']}-{r['idx']}: json {r['json_s']}s, "
                  f"turns {r['turns']} — treat turn count as unreliable for this run")

    cache_share = statistics.mean(
        r['cache_read'] / max(1, r['cache_read'] + r['out_tok']) for r in rows)
    print(f'\nCache reads are {cache_share:.0%} of the tokens that carry cost: notional cost '
          f'tracks context size, not output volume.')


if __name__ == '__main__':
    main()
