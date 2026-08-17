# 5.16.0 — the review costs what the human hasn't already paid

`/finalize-workflow`'s pre-commit review ran the same way on every run: a
whole-diff `code-review` pass, `medium` effort on interactive plans, `high` on
autonomous ones. On an autonomous run that is money well spent — nobody ever
read that code. But on an interactive run the user vetted every phase as it
landed, diff by diff, at the approval gate. Charging them the full extended
pass again at the end re-buys what they already own.

What the interactive user has *not* paid for is one specific thing: every
phase was born in a fresh session and verified in isolation, so **nobody —
the user included — has ever seen the diff as a whole**. That residue is
cross-phase by definition: one phase breaking another's assumption, the same
helper written twice by sessions that never met, naming drifting along the
way. It is much cheaper to hunt than a full review, because it is all that is
left to hunt.

## The depth is a question, the recommendation is computed

Step 4 now asks once — **Extended / Light / None** — instead of deciding
alone, and computes the recommended option from what finalize already knows
by then:

- **A human eye lands on the result** — the QA pass exercises the
  deliverable, or the user vetted each phase interactively → **Light**:
  effort `low`, scoped to cross-phase issues only.
- **Nothing human ever looks at the work** — internal changes, no QA checks
  on the deliverable, or the user declined the QA pass → **Extended**: the
  review is the only eye the work gets. `medium`, `high` on autonomous plans.
- **`> Review:` notes or a `## Run inspection` section exist** →
  **Extended** regardless: those notes were flagged precisely because nobody
  was reading. Whatever the user picks, the notes are never dropped —
  Extended and Light must confirm or explicitly dismiss each one; **None**
  presents them raw for the user to judge alone.
- **None** is always on offer, its price stated in the option itself: the
  workflow closes with no one having seen the whole diff.

On large autonomous diffs a fourth option joins the question — the reviewer
**panel** of 5.11.0, recommended there in place of Extended. The worktree
path is exempt from all of this: the finalize agent's prompt ships fixed in
the plugin, and that fixity is what keeps its review independent.

Two smaller leaks close with it: the `report-judge` comprehension probe is
skipped when the review returns no findings (a clean verdict line has nothing
to misread), and the mode of the plan no longer decides the effort by itself —
it only weighs on the recommendation.

## The QA pass becomes a page you tick

The other half of the release is the input that recommendation reads. The QA
pass — every `Verify:` step plus the deferred checks accumulated in
`verify.md` — used to arrive as a list in chat: read it, scroll away, lose
it. It is now a **QA page**, sibling of 5.14.0's report page and defined next
to it in `common.md`: a manual test plan rendered to a file
(`${TMPDIR:-/tmp}/phased-workflow/<slug>-qa.html`, outside the tree), one
checkbox per check, grouped by phase, each item naming the action to exercise
and the result the user should see, deferred steps whose phase has since
landed marked as now due.

The checkboxes are the user's own tracking while they work through the list —
purely client-side, nothing reports back to the session, and the skill still
asks its one question about the outcome afterwards. It is a work sheet, not a
closing report, so the report-judge gate does not apply to it. Where nothing
can render a file (CLI, headless), the degradation is declared: the same
list in chat, grouped by phase, exactly as before.

## Guarded

S33 joins the orchestration suite: `common.md` owns the QA page and its
filename (no skill may hardcode it), finalize delivers the QA pass as that
page and still asks the depth question with Light scoped to cross-phase
issues only, and the zero-findings probe skip stays in place. Three
mutations prove the guard bites. The suite is green at 202.
