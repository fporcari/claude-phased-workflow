# wf eval suite

Run from the plugin root (`plugins/wf`) after `claude update` >= 2.1.269.

Routing only, one arm, cheap first pass:

    claude plugin eval . --tag routing --runs 1 --ablation none --no-publish

Behavior case (needs git and the plugin's python scripts, and the case's scaffold):

    claude plugin eval . --tag behavior --scaffold --allow-tools "Bash(git:*)" "Bash(python3:*)" --runs 1 --ablation none --no-publish

Full run with the no-plugin baseline (default ablation), 3 runs per case:

    claude plugin eval . --scaffold --allow-tools "Bash(git:*)" "Bash(python3:*)" --max-cost-usd 10 --no-publish

`tool_used: Skill` graders are plugin-fired indicators under ablation, not part of the score; the `min: 0 / max: 0` ones carry `arm: both` so a skill firing where it must not costs points in both arms.

`resume-reports-state/fixture` is a copy of `tests/benchmark/fixture` (plan + textutils); keep them in sync by hand.
Results land in `results/` (gitignored).

Outside an interactive terminal (CI, Desktop background shells) add `--trust-plugin`: the first run in a terminal trusts the directory once instead.
