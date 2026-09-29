# Sonnet 5.5 vs Opus 5.5 — partial run, 2026-09-29

`sonnet55.sh 3`, shipped `/goal` contract (sha `8c33dd4315c3`), plain `fixture/`.
Stopped by hand during the first `sonnet55-high` run to save credits: `BENCH_OUT`
archives only at the end, so these rows are transcribed from the terminal and no
session JSON survives. `fixture-seeded/` — the hidden edge case — was not run.

| config | run | outcome | turns | cost_usd | duration_s |
|---|---|---|---|---|---|
| opus55-low | 1 | success | 10 | 0.394 | 68 |
| opus55-low | 2 | success | 9 | 0.376 | 62 |
| opus55-low | 3 | success | 9 | 0.394 | 58 |
| opus55-medium | 1 | success | 10 | 0.428 | 83 |
| opus55-medium | 2 | success | 11 | 0.432 | 98 |
| opus55-medium | 3 | success | 10 | 0.477 | 77 |
| sonnet55-medium | 1 | success | 11 | 0.419 | 40 |
| sonnet55-medium | 2 | success | 16 | 0.451 | 45 |
| sonnet55-medium | 3 | success | 17 | 0.467 | 48 |

Means: opus/low $0.388, 63s · opus/medium $0.446, 86s · sonnet/medium $0.446, 44s.

Reading: on an easy, fully specified phase every arm succeeds; Sonnet 5.5 at
`medium` takes more turns, which eats its halved token price — it costs what
opus/medium costs and ~15% more than opus/low, but finishes in half the time.
Three runs per arm on one task: a direction, not a statistic. The decision
rule in `sonnet55.sh` was not applied; 6.41.0 reopened the palette on the
docs instead (see `docs/design-notes.md`).
