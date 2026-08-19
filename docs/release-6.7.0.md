# 6.7.0 — the stop-loss, the map, and the lessons ledger

Three failure modes were on the table. A defect with a good plan already had
its road (6.6.0: the defect leaves the phase chat). A good execution of a bad
plan already had its road (6.3.0: the rejected result re-plans what has not
run). The third had a channel but no trigger: a phase chat with a *hidden*
plan ambiguity does not know it has one — it thinks it is struggling with the
implementation, and it spends its context debating the symptom with the user.

## The stop-loss

`clarify?` no longer waits to be recognized: **struggle is the symptom of an
ambiguity nobody has named**. The second failed attempt at one obstacle, or an
exchange that has turned from deciding into diagnosing why the approach does
not work, stops the phase — checkpoint, then the suspected presupposition goes
to the foreman (*assuming X — does it hold?*). Never a third attempt, never
another diagnostic message in the phase chat. The answer lands on known
ground: presupposition holds → it is a defect, and it leaves the chat;
presupposition false → the plan is wrong there, and the ordinary clarify and
rejection roads apply. Canon in `common.md` → *The foreman*; `/execute-phase`
cites it at Step 4.

## `/wf:help`

A router in the ask-matt style, not a manual: *where are you?* → the command
that takes the work forward, plus a one-line-per-command table. It reads no
state — that stays `/resume-workflow`'s job — and the README keeps the full
cheatsheet, so nothing is written twice.

## The wf-lessons ledger

A misunderstanding that reached the foreman is evidence about a **skill**, not
only about the plan that suffered it. So the foreman, after answering a
`clarify?` or receiving a `result rejected`, appends one entry to
`~/.phased/wf-lessons.md`: what failed, why the skill's own procedure let it
through, and a proposed patch as before-text → after-text. **A proposal,
never a patch**: nothing edits the installed plugin, a human consumes the
ledger in the plugin's own repository and ships what deserves shipping as a
release. Best-effort like every foreman action — a lesson never blocks a
reply, a phase, or a run.
