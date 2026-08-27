# Changelog

One entry per release, newest first — a paragraph by design. The fuller
narrative notes that accompanied 4.1.0–6.7.0 (`docs/release-*.md`) were
consolidated here and remain readable in the git history.

## 6.26.1 — 2026-08-27

Five findings the 6.26.0 review left open, all in the dashboard. Two dashboards on one machine could not find each other any more: once every read needs the token, the reuse look — a blind `curl` over the listening ports asking each `/api/state` which repository it watches — recognises nothing, so a second `/wf:dashboard` on the same repository started a second server. A live server now leaves an owner-only registry entry beside its queue and `server.py --probe` reads it, confirms over the authenticated endpoints that the server still answers for THIS repository, mints a fresh one-shot for the new pane and removes a stale entry itself; `lsof`, `curl`, `grep` and `sort` leave the skill's `allowed-tools` with the loop that needed them. The `one unattended run per plan` guard read the queue under one lock and appended under another, so two presses landing together both found it empty and both queued — check and append are now a single locked step. The queue's transport directory is 0700 and its files 0600 explicitly rather than by whatever the umask leaves: `/tmp` is shared on a multi-user host, and the queue names repositories and carries commands. And the closing header, asked for the LAST finalized plan, returned whichever slug sorted first among the branches: candidates are now ordered by the commit that last touched each plan on its own branch. Four new tests, 29 in `tests/wfdash/`, all of them under S51.

## 6.26.0 — 2026-08-27

The eighteen findings the 6.25.0 graft recorded and did not fix are closed — the consolidation that dropped `.phased/` from that branch is why they survived only as a document. Two of them blocked anyone running two dashboards at once. The session cookie carried no port, so a second page on `127.0.0.1` evicted the first and the first could not recover, its one-shot being spent; the cookie is now named per port, verified in a browser with both ports still answering. And the `one unattended run per plan` guard, deleted along with the server's authority and never re-established, is back — in the queue, where it now lives, bounded by an age past which an undrained request stops blocking the button for good. The queue itself survives two processes: an `fcntl` lock on a sidecar plus a rename-aside drain, copy-adapted from the in-house atomic-file pattern, so a press landing mid-drain is no longer destroyed by the `read`-then-`remove` pair it used to fall into. The plan format goes back to ONE reader — `next-phase.py --json` reports each phase's line span and the dashboard's own block slicer is deleted; S18's guard had missed it because its marker was written escaped, and now sees that form too, proven by mutation — and the reader is imported once instead of spawned on every five-second poll. The perimeter answers 403 on a non-ASCII credential instead of raising out of the handler, the token is compared in constant time, and the session cookie is granted once rather than repeated on every keep-alive response. What the payload knows now reaches the page: phase tags render as chips along the whole road (the grid's row projection dropped them, which no page-side test could see) and the header says which of the five outcomes the plan is in, not two. `parse_plan`/`parse_plan_text`, `wHeaders()` and the caller-less `GET /api/agent` are gone with their call sites. The README's changelog table regains 6.24.0 and its suite figures are re-measured against the real counts, both held from now on by `check_readme_continuity.py` — the stale claim they replace is what cost the previous plan eight defects of its own.

## 6.25.0 — 2026-08-27

The wfdash dashboard ships as an ALTERNATIVE surface, with the textual report staying the default and the only mandatory one: `/wf:dashboard` opens a local, read-only view of the plan as a tree — phases, the agents that ran each one, what they are doing now and what it cost — and no skill of the plugin needs it to carry work forward. Two things had to change before it could ship. The HTTP perimeter, which handed its write token to any local process that asked for the page, now authenticates every request, reads included, through a one-shot key exchanged for an `HttpOnly` cookie, with no token slot left in the page. And the server's authority over the work is gone: it spawned the launcher and wrote into the supervision chat, bypassing the skills that own an unattended run and the foreman channel — now the page PROPOSES, queueing a request the chat drains into `/wf:run-workflow`, `/wf:execute-phase` or `refs/foreman.md`, and the ticks are a reading of the phase's `Done:` criteria rather than a state anything persists. The optionality is enforced, not promised: `check_optional_surface.py` holds every dashboard mention across the skills and refs to stating or citing its fallback and refuses any that makes the page a precondition, and the 15 wfdash tests run as scenario S51 of the suite under both shells. `docs/wfdash.md` is the manual; four new read surfaces (the transcript JSONL, `claude agents --json`, the task todo files, `~/.claude/sessions/<pid>.json`) enter the compatibility baseline, flagged as costing the page and never a workflow.

## 6.24.0 — 2026-08-26

An audit of every prompt the plugin builds for a subagent, a sub-session or a worker, read against the prompt-forge criteria, found the same defect S26 was written for one surface over: an agent spawned by NAME resolves like a slash command, and eight citations named the shipped judges bare. A bare name is not an error the session reports — it finds an un-namespaced copy left by an older flat install (which really did keep a stale verifier running on the author's own machine) or nothing at all, and the skill then falls through to its declared general-purpose fallback, losing the shipped prompt in silence. Both outcomes read as a working spawn in the log. Every backticked citation is now `wf:phase-verifier` / `wf:ui-judge` / `wf:report-judge`, and S50 guards it from the shipped agent set rather than a retyped list, proven by mutation. Four more findings from the same pass: the `Panel` review option promised "under ~15 agents" while its own fan-out reached 40, so the count is now fixed by construction (4 dimensions + the 4 most severe findings × 3 skeptics = 16) with the return format and the truncation both declared; the `vast` fan-out and the planning skills' Explore waves gained the caps and return formats they lacked, `NO SITES`/`NO CANDIDATE` included; the launcher's steer dropped the comment-density and subagent-delegation clauses that `--append-system-prompt` was stacking on top of the `claude_code` preset's own; and `agent-session.sh` gained the runaway cap its sibling phase sessions already had. `/doctor`'s blind author now closes with `READ:`, so its blindness is audited instead of merely instructed.

## 6.23.0 — 2026-08-20

The plan-defect consult gains its missing third answer: the sql-recipe-pipeline field run hit a claim that arrived with its one-line fix already written and proven in the `> Issue:` — repair was disproportionate spend, stop killed the rest of the run. `plan-defect: apply` covers exactly that case: the launcher keeps holding on a second file (`<slug>-apply-outcome`, window `RUN_WORKFLOW_APPLY_TIMEOUT`, default 900s) while the run's inspector — the one session attached to the workspace — applies exactly the declared edit to both contract copies byte-identically, re-runs the phase's `Done:`, and on green flips the phase `[x]` (`> Applied:` note, `> Issue:` kept) and commits; the launcher then continues with the next phase, no repair session and no relaunch. Red, a timeout, or a green that left the `[!]` standing all fall through to the repair, which judges the claim as before. The road is licensed, not open: contracts.md now requires the claim's edit as before-text → after-text, and the foreman offers apply only when that form is there — an apply that grows into a rewrite is a stop wearing apply's clothes. S49 guards it live (green, red, timeout, unbelieved green) and static (owned by foreman.md, spoken by the inspector, licensed by contracts.md, shipped in the launcher), proven by mutation.

## 6.22.0 — 2026-08-20

The run gains a clean "finish the phase in flight, then stop": with credits counted, the sql-recipe-pipeline field run had no channel to say it, and the workaround — an external kill on the closing EVENT line — raced the next phase's launch, off protocol. The launcher now checks `${TMPDIR:-/tmp}/phased-workflow/<slug>-stop-request` between sessions (the same outside-the-repo transport as the consult answer file), consumes it, and ends the run as `EVENT: run-end stopped-by-request N/M` without launching another phase — no `[>]` left behind, no reset needed at relaunch. A stale request from an earlier run is removed at start, declared. `RUN_WORKFLOW_MAX_PHASES=N` states the same bound upfront — at most N more phases, counted on phases landed, not sessions — which is how "run only phase 8, hold phase 9" is said. S48 guards both live (mid-run stop, stale request, budget hit, unspent budget, non-numeric budget) and static, proven by mutation.

## 6.21.0 — 2026-08-20

A contract test's prohibition is now checked against the other phases' law before the plan ships: the sql-recipe-pipeline run planned a phase-7 test banning a name form that phase 4's golden file and phase 6's round-trip made mandatory — a defect present since planning, surfaced only as a mid-run consult at the price of a failed session. `/write-workflow`'s autonomous branch gains a dedicated negative-assertion sweep after contract-test authoring: every forbidden substring or shape is compared with the `Decisions:` and `Done:` of every other phase — golden files and round-trips included, whose outputs are law for the phases that follow — and a prohibition another phase's law can force is resolved before launch. `/run-workflow`'s inspector complements it at runtime: a phase that closes on a bent decision triggers a re-read of the pending phases' contract tests against the bend, so the collision surfaces while stopping is still cheap. S47 guards both ends, proven by mutation.

## 6.20.0 — 2026-08-20

A killed unattended run now names itself at resume: a host-app restart takes the launcher, its Monitor and the phase session down in one blow (sql-recipe-pipeline field run), and the only channel that survives is the EVENT log the launcher tees outside the repo. `/resume-workflow`, on finding a stale `[>]` alongside a run log at `${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log`, now says explicitly that an unattended run was in flight when everything died, reads the log's last `EVENT:` lines to report how far it got, and offers the reset + relaunch as one option — Step 4's stale-`[>]` reset, then a fresh `/run-workflow` over what remains — because the reset alone leaves the user without the path back. S46 guards it (the shared log path on both skills, the mid-flight wording, the offer), proven by mutation.

## 6.19.0 — 2026-08-20

Minimality covers surface and prose alike: the contract names the over-engineering idioms once — accessor methods for attributes the language already exposes as public, wrappers that only delegate, comments narrating the line below, docstrings restating the signature, guards for unreachable states — with the repo's own comment density as the only measure. The phase verifier hunts them (extra surface stays JUDGMENT, empty prose is MECHANICAL: remove), the naming review's Necessity column flags the named idioms with every new callable in one view, and the launcher's common steer prevents them on every unattended session — light mode included, which no verifier ever sees. No new pass and no extra sessions: prevention in the steer, detection where the checks already run. S45 guards the chain (contract → verifier → steer → naming review), proven by mutation.

## 6.18.0 — 2026-08-20

The close splits in two, back to the original intent: `/quality-check` takes the quality half of the old finalize — completion check, the QA pass in the user's hands, the naming review of what autonomous phases created, the roadmap/scope coherence look, and the pre-commit review at the depth the user picks (an argument on the invocation pre-answers it) — and ends by stamping the plan (`> Quality check: <ISO> — commit <hash> — review <depth>, QA <answer>, findings <summary>`, single-source in `contracts.md`). `/finalize-workflow` now does only the closing: it gates on the stamp — missing or stale (commits after it) → one question, run `/quality-check` first (recommended) or close without it with the price stated — then lessons, plan archive, and the consolidation proposal (PR / merge / commit only). The read-only verify agent follows its skill (`finalize-workflow-agent` → `quality-check-agent`), every guard that watched finalize's quality steps was repointed (S27, S31–S33, S37, S38), and S44 guards the stamp: owned by contracts.md, written by quality-check, gated on by finalize, proven by mutation.

## 6.17.0 — 2026-08-20

A child claiming the plan is at fault no longer walks straight into an unattended repair: it closes `[!]` with `> Issue: plan-defect claim — …` (the token is single-source in `contracts.md`), and the launcher holds the repair, emits `EVENT: phase-needs-foreman` and polls an answer file outside the repo while the run's inspector relays the claim to the foreman as the third question, `plan-defect?`. The foreman puts one question to its user — authorize the repair (the recommended default) or stop the run — and on a stop the plan fix is the foreman's own work: it edits plan and contract tests, commits, launches `/repair-phase` itself where the committed code needs it, and relaunches. No answer within the window (`RUN_WORKFLOW_CONSULT_TIMEOUT`, default 600s) falls through to the repair — deliberately: in the first field run (sql-recipe-pipeline) both claims were wrong and the fresh-eyes repair found the better design each time, so repair also gained the twin duty of *testing* the claim as written before confirming it (`> Repair attempted: plan-defect confirmed`). Repair transcripts now land per phase (`log/repair-N-fable.txt`) — the old fixed name let one repair overwrite another's only record. S43 guards the gate live (timeout, stop, repair, no-claim bypass) and static (token single-source, spoken by every consumer), proven by mutation.

## 6.16.0 — 2026-08-19

The doctrine mass becomes a measured quantity: `check_doc_mass.py` computes every skill's closure — its SKILL.md plus every ref it cites, the doctrine a session ingests before working — and S41 fails the suite when a closure exceeds the 1500-line budget or cites a ref that does not ship (`--report` prints the table). Growth now pays its budget at merge time instead of degrading sessions in the field; today's worst case is close-phase at 1392.

## 6.15.0 — 2026-08-19

The messaging channel is declared, not discovered: `foreman.md` gains *Channel floors* — the single source of the version floors the messaging layer rides (CLI `SendMessage` ≥ 2.1.224; the launcher's own 2.1.139/2.1.170 floors stay runtime-detected) — and the state-reporting skills (`/resume-workflow`'s report, `/run-workflow`'s first relay) say in one line which branch is alive in this installation, so a dead channel reads as declared degradation instead of surfacing later as a silent skip. The compatibility baseline carries the floor table, so the daily update check flags any drift. S40 guards it all, proven by mutation.

## 6.14.0 — 2026-08-19

The doctrine splits by consumer, so a session pays only for the layers its skill uses: `common.md` (860 lines, read by everyone) becomes a 250-line core plus `contracts.md` (Done:/Verify:, contract tests, Must not break:, markers — planning, execution, close, doctor, finalize) and `foreman.md` (hierarchy, messaging, ledger, register, notifications — the skills that supervise or report). A headless phase session drops from ~1140 lines of doctrine to ~790 and defers the foreman layer entirely — it reads only the message formats, at the notify step. Every static guard was repointed and re-proven by mutation, and every mutation dir now starts from the full pristine refs set, so a guard reading several refs can no longer pass vacuously on a file the mutation did not touch.

## 6.13.0 — 2026-08-19

Sonnet leaves the model palette: field experience regretted every sonnet phase — the first-pass-success bet kept losing, and a failed sonnet phase costs a fable repair. Mechanical work is now `opus` at `low` effort, where light mode already strips the ritual that was sonnet's supposed saving. The launcher still accepts and steers legacy plans that carry it (accepted is not recommended), and the independent verifier keeps its sonnet trigger for those plans only.

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
