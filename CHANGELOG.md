# Changelog

One entry per release, newest first — a paragraph by design. The fuller
narrative notes that accompanied 4.1.0–6.7.0 (`docs/release-*.md`) were
consolidated here and remain readable in the git history.

## 6.12.1 — 2026-08-19

Sessions are not phases: the launcher's loop budget was the initial `[ ]` count, so a phase resumed from `[>]` — or a repair round — consumed two iterations for one decrement and the tail of the plan silently never ran (S10 and S11 had even ratified the starvation). The bound is now twice the pending count, every deliberate stop names itself, and exhausting the bound with work still pending is declared out loud instead of reading like any other stop.

## 6.12.0 — 2026-08-19

The programme is a graph, not a chain: Macro 5 may require what Macro 2 builds with other macros in between, so a contract lives from producer to consumer and every macro it crosses inherits it into its own `Must not break:` — you saw the Uffizi on the Italy leg to compare them with the Prado on the Spain leg, and no leg in between may lose that luggage. The coherence judge flags intermediate macros whose scope plausibly destroys what crosses them, each macro's planning inherits the contracts in transit, and finalize's roadmap check treats lost luggage as a finding.

## 6.11.0 — 2026-08-19

The macro split is scoped, not just listed — the split moment is the only one with the whole programme in a single context: every macro gets a mini-scope (objective, `Starts from:`/`Ends at:`, `Delivers`, `Consumes`, `Requires of earlier work`, open decisions) with user questions batched once, a fresh-context coherence judge checks the itinerary first (each `Ends at:` must be the next `Starts from:` — the Italy leg must not end in Puglia) and the contract graph second, and downstream the consumer question reads the later macros' `Requires` lines instead of memory while finalize compares the state actually delivered with the declared border.

## 6.10.1 — 2026-08-19

The programme contract reaches the unattended path too — the one macro-phases actually run on: the light-mode goal contract now names `Must not break:` as later phases of the same rank, and `/run-workflow`'s inspector reads the header and the roadmap's remaining macros in its per-phase coherence look.

## 6.10.0 — 2026-08-19

A future consumer's contract travels backwards (issue #15): the plan header gains `Must not break:` — contracts owned by later macro-phases, filled by planning's new consumer question and backed by `wf:contract:` skeletons — the gate's compatibility line and the plan-is-context skim rank it with pending-phase premises, `/finalize-workflow` checks the landed macro against the roadmap's remaining bullets (now carrying *who consumes it*), and `/doctor` turns a consumer measured late into skeletons run against what an earlier macro built — the reds are the measured gap.

## 6.9.0 — 2026-08-19

`/doctor` asks whether the work is still coherent with the plan: a cheap audit of pending premises against what actually landed, contract-test integrity on plans that have them, and — on plans that predate 6.8.0 — a blind retro-fit: one agent authors the missing tests from the plan's promises alone (a sighted author would ratify the code's own deviations), a second fills the skeleton bodies against the real code and runs them phase by phase. Red on a completed phase is a finding, never a fix and never a reopen — remedies stay with `/resume-workflow`.

## 6.8.0 — 2026-08-19

The contract between phases becomes enforceable: planning can author every phase's tests up front — executable where the surface is settled, skeletons (`wf:contract:` lines + red body) where it is not — `ui` checks are pre-established in the plan, the gate states in one line what the phase leaves standing for the pending ones, and any change of contract routes through the foreman: no child rewrites what the plan authored.

## 6.7.1 — 2026-08-19

A repair says so on the plan: the chat names the phase it is repairing, and `[!]` stops being ambiguous between broken and being-worked-on.

## 6.7.0 — 2026-08-19

Struggle routes up before it burns tokens (the stop-loss), `/help` maps the commands, and every misunderstanding leaves a skill-patch proposal in the wf-lessons ledger.

## 6.6.0 — 2026-08-19

Repair splits in two: with you it asks what is wrong and hands the phase back, unattended it closes on its own — and a defect found mid-phase leaves the phase chat.

## 6.5.0 — 2026-08-19

A phase that outgrew its chat closes on what it reached: the `Done:` is corrected to the truth and the foreman grows a phase for the remainder.

## 6.4.0 — 2026-08-19

Handing over a long phase is a move you can call, a tool you have not loaded is not a tool that is absent, and a phase chat does not supervise.

## 6.3.0 — 2026-08-19

A rejected result travels up as its own line and re-plans the phases that have not run — no `[x]` and no report before you have answered.

## 6.2.1 — 2026-08-19

Rejecting a result at the test gate no longer marks the phase `[!]`: its tests are green, so what changes is the decomposition.

## 6.2.0 — 2026-08-19

The board becomes a strip you read: the controls go back to the conversation, which now carries remarks upward on its own.

## 6.1.0 — 2026-08-19

A phase with checks left to you does not close itself: work committed, phase open, `/close-phase` on your ok — and the foreman answers a phase report with the delta, not a redrawn board.

## 6.0.3 — 2026-08-19

The chat titles itself — the foreman's rename was the last manual step — and the messaging channel is tried `list_sessions` first.

## 6.0.2 — 2026-08-18

The clarify decision survives a dead reply: committed to notes first, the plan edit travels in the reply, the child applies it on acceptance.

## 6.0.1 — 2026-08-18

Field-tested `clarify?`: the foreman replies before touching the plan, and take-command advises the permissions an unattended reply needs.

## 6.0.0 — 2026-08-18

The plugin is renamed `wf`: the command prefix stops swallowing the skill name — `/wf:execute-phase`.

## 5.18.0 — 2026-08-18

`clarify?`: plan ambiguities in interactive phases go to the foreman first; the human confirms the decision in the child chat.

## 5.17.1 — 2026-08-18

The foreman commands and does not execute: no skill sends the next phase back to the chat that holds the plan.

## 5.17.0 — 2026-08-18

New methods are born marked, their names reviewed in one map — one keypress to accept all — and `/close-phase` closes the phase.

## 5.16.0 — 2026-08-17

The QA pass becomes a tickable checklist page, and finalize's whole-diff review asks its depth — light where a human eye already landed.

## 5.15.0 — 2026-08-12

The plugin stops choosing the conversation language: English canon for every shipped wording, the language follows the user.

## 5.14.0 — 2026-08-11

Closing reports get a shape — verdict plus one line per finding — a comprehension-probe gate, and a report page with detail behind a click.

## 5.13.0 — 2026-08-11

Workers read the whole plan as context, the inspector watches cross-phase coherence, and reports speak the decision-maker's language.

## 5.12.0 — 2026-08-08

The `ui` tag: mockup gate at approval, browser pass with human login, and the ui-judge.

## 5.11.0 — 2026-08-08

The run inspector: per-phase events relayed to the foreman, and the stop-work question.

## 5.10.1 — 2026-08-08

The foreman field-tested: the title is the address, the user's rename is the one manual step.

## 5.10.0 — 2026-08-08

The foreman: one chat commands the workflow, phase chats report to it over cross-session messaging.

## 5.9.0 — 2026-08-07

A skill that waits says so: the gate line, one gate at finalize, no fake questions.

## 5.8.0 — 2026-08-05

The resume path leaves evidence a fresh session can diff, and the version claim is checked.

## 5.7.1 — 2026-08-05

`problema` is two things, and only one of them is repairable.

## 5.7.0 — 2026-08-05

The board becomes a working view, shared by planning and supervision.

## 5.6.1 — 2026-08-05

The board's controls become mandatory, and the chip opens in the plan's root.

## 5.6.0 — 2026-08-05

`Run:` hint on interactive plans, and a board in `/resume-workflow`.

## 5.5.0 — 2026-08-05

The rename reaches the guide, and busts the plugin cache.

## 5.4.0 — 2026-08-03

Invocation discipline, and `/scope-workflow`.

## 5.3.0 — 2026-08-05

Per-model prompt steering for autonomous sessions.

## 5.2.1 — 2026-08-05

Act on the adversarial review of 5.1.0–5.2.0.

## 5.2.0 — 2026-08-05

Interactive mode as a first-class mode.

## 5.1.0 — 2026-08-05

The unattended run.

## 5.0.0 — 2026-08-05

Command surface, plan location, workspace lifecycle (breaking)

## 4.1.0 — 2026-08-05

Acting on the external review of 4.0.0.
