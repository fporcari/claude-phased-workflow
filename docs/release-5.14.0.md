# 5.14.0 — the report shape, the comprehension probe, and the report page

One field report, and it is a follow-up: asked whether 5.13.0's reporting
register had fixed the closing reports, the same colleague who prompted it
answered *"diciamo che mi fa ancora supercazzole"*. The diagnosis writes
itself once the answer is taken seriously: the register governed
**vocabulary** — name things by what they do, defects as consequences, no
bare identifiers — and said nothing about **volume**. Every sentence obeyed
the rules; the total was still a wall. A wall of clear sentences is still a
wall.

Two proposals came out of the same conversation, and they turned out to be
halves of one fix. The colleague suggested a gate: pass the report to an
agent that does not know the code, only the rough context — if it
understands, ship; if not, rewrite. The other proposal was an interactive
sync: instead of dumping everything, let the reader pull. This release
ships both — each in a stronger form than first drafted — plus the piece
neither of them named: a hard structural cap on the report itself.

## The shape

The register (still single-sourced in `common.md`) now owns a structural
contract, not only a lexical one: the short form IS the report. One verdict
line first — landed or not, and the single fact that matters most — then
one line per finding, and nothing else. Detail is never volunteered: the
artifacts hold it, the reader pulls it. This is the cap 5.13.0 lacked, and
it is what the colleague's feedback was actually about.

## The report page

The first draft of the pull mechanism was a question flow — and it died in
review twice. "Ask about detail only if a human is present" fell apart
because `/finalize-workflow` can only ever be launched by a human: the real
cut is not presence but whether the channel admits a reply. And a chain of
yes/no questions taxes the reader's time as surely as the wall taxed their
patience. The form that survives is hypertext: where the session can render
a file to the user, the closing report is a **report page** — the verdict
on top, one line per finding, each finding a closed `<details>` expansion
opening on its detail, drawn from the plan artifacts. The reader pulls at
their own pace; no question is asked at all. The page lives outside the
repo (a file in the tree would dirty it) and outlives the chat — the
decision-maker the register was written for can read it without ever
entering the session.

The cap survives inside the expansions, deliberately: each `<details>`
answers a precise question of the decision-maker, never the phase
chronicle. Progressive disclosure is not an alibi for putting the wall
back one click away.

Degradation is declared, as everywhere in this plugin: without a way to
render the page (CLI, headless), the short form lands in chat and exactly
ONE question governs detail — dedicated (*Espandi tutto / Scelgo io quali /
Basta così*) when the report ends the exchange, folded as an extra option
into the decision question the skill already asks when there is one
(finalize's *fix-first-or-proceed* gains *Espandi i dettagli prima di
decidere*), never two questions stacked: the stop-work precedent. The
one-way surfaces — foreman one-liners, push notifications, the `stop-work?`
reason — carry the short form only: never a page, never the question.

## The report-judge, as a comprehension probe

The plugin already had the argument for this agent, in 5.12.0's ui-judge:
*the author of a UI is the worst judge of its own fidelity*. The same
sentence holds with "report" and "clarity" substituted in. But the naive
version of the gate — "ask an LLM if the report is clear" — would approve
walls of text every time: pointwise LLM judging carries a documented
verbosity bias, and every sentence an LLM writes is individually clear to
another LLM. The literature that studies this converged on a stronger
design years ago: judge a summary not by opinion but by whether questions
can be *answered from it alone* (QA-based evaluation — FEQA and QAEval,
2020 onward), and validate simplified reports by giving naive readers a
comprehension test, not by asking them if the text felt clear.

So `report-judge` ships as a test reader, not a critic. Fresh context by
design, it receives the draft verbatim — for a report page, its collapsed
layer only: the report must work with every expansion closed — and a
one-line brief of what the workflow was about; not the code, not the plan,
not the session. It first retells, in its own words, what it understood
happened — the colleague's principle taken literally: hand the report to a
virgin agent and hear what it would understand, because a misreading (a run
event read as a product fact, a repaired defect read as still open) shows
up only in a free retelling. Then it must answer the decision-maker's three
questions from the draft alone — did it land? what do I decide now? what is
still pending? — writing `CANNOT ANSWER` where the draft does not say,
never guessing, and flagging as `OPAQUE:` every sentence it could not put
to use.
The caller, who holds the artifacts, compares the answers with the truth: a
wrong or missing answer names exactly what the report buries. Rewrite,
re-probe once, show. No opinions anywhere in the loop.

Best-effort like every notification: no Agent tool, or the judge errors →
the report is shown anyway, with a note that the gate was skipped.
One-liners and pushes are not gated — they are one line by construction.

## Guarded by S32

By mutation, as always: common.md stops owning the shape → fail; it loses
the report page → fail; a closing-report skill drops the gate citation →
fail; the agent file goes missing, or loses the `CANNOT ANSWER` convention
that keeps the probe from guessing → fail; a skill restates the shape
instead of citing it → fail. `run-workflow` gains the Agent tool in its
allowlist, and the guard checks that too — a cited gate that cannot run is
prose. 198 assertions over 31 scenarios.
