# Changelog

One entry per release, newest first — a paragraph by design. The fuller
narrative notes that accompanied 4.1.0–6.7.0 (`docs/release-*.md`) were
consolidated here and remain readable in the git history.

## 6.33.1 — 2026-09-02

Fable 5.1 has a price, and its cache reads have their own. Surfaced by the 2026-09-02 `/check-claude-update` run: `claude-fable-5-1` shipped as the new default target of the `fable` alias — the alias `run-workflow.sh` hardcodes for every repair session, and the one any phase pinning `Model: fable` gets — while `scripts/wfdash/core.py` priced `claude-fable-5` only, so every fable session from that release on landed in `self.unpriced` and the dashboard's cost total silently dropped all of its tokens. The `PRICES` row alone would have stopped the flag and told a second lie: the file computed cache reads as a flat `0.1x` of input for every model, which on a $10/Mtok input model is $1.00/Mtok, where Fable 5.1's actual rate is **$0.25/Mtok** — a per-model rate, not a multiple of anything. So cache reads gained a table of their own, `CACHE_READ`, read through `cache_read_rate(model, pin)`: a model named there is billed at its own rate, every other model keeps the 0.1x the rest of the table follows, and the next model that prices its cache separately is one line. `test_core.py` pins a Fable 5.1 session as priced and its million cache reads at $0.25, a figure both the missing row (0) and the row-only fix (1.00) fail.

## 6.33.0 — 2026-09-02

The foreman's own model is a written hint, like `Run:`. Every phase carries `Run: <model> / <effort>` because a chat's model and effort are chosen when it opens, before any skill has read the plan — and the same was never said of the chat that commands, so a foreman ran on whatever the user's defaults were (`xhigh`, the global setting) and its choice was invisible. The policy, written once in `foreman.md` → *The foreman's own model*: **`fable` / `high`**. The foreman's output is judgment and prose to humans — a plan-defect consult answered, a QA question worded, a closing report — where `opus` reads flat and `sonnet` invents; `high` because the QA fix (6.32.0) is code, and `xhigh` on pre-digested input is overthinking. Nothing enforces it, exactly as with `Run:`. The two places a next foreman is opened from repeat it: `/write-workflow`'s closing line (a successor foreman chat) and `/resume-workflow`'s *Next step* when it names a fresh chat because the foreman is gone. S61 pins the paragraph, its value and both repetitions, by mutation. The paragraph's seven lines in `foreman.md` are paid by pure re-wraps of its longest paragraphs, so every closure stays under the doc-mass ceiling.

## 6.32.0 — 2026-09-02

Once every phase is `[x]`, the foreman fixes what the user's own check turns up — it does not plan it. Field case, the tail of the same gnrwork run: the phases had landed, the user exercised the QA list and reported two things in two sentences — `al` mandatory as on the worker's form, and "deny" shown untranslated — and the foreman, bound by *commands, does not execute* and by `/quality-check`'s "NO source code editing", turned them into Phase 11: a plan refine, three commits, a four-minute session and an inspection note, for two edits and one commit that were owed. The **QA fix** is now the foreman's second declared exception, beside launching `/run-workflow`: a correction the user states in one sentence at the quality check, applied and committed by the foreman itself, because with the human at the gate and no phase left to command a phase's ceremony buys nothing. The boundary is a correction, not a design — the user's sentence is the whole decision: a wrong term, a label, a field's rule or default, a missing catalog entry; no new table, column or migration, no engine change, no new surface or callable, only files the phases already touched plus the catalogs that serve them. `/quality-check` → *QA fixes* carries the mechanics — suite and lint on the touched files, one `wf: qa fix — <one line>` commit per QA round, each recorded in `notes.md` under `## QA fixes` as *what the user saw → what changed* — and `/finalize-workflow`'s lessons pass reads that section, because every fix a human had to ask for is a `Verify:` or `Decisions:` line the plan did not author; beyond the boundary the correction is still a phase, and the chat says which road it took. `/run-workflow`'s closing pointer says the same. S44 pins the exception in the ref, the paragraph in the skill, the lessons pass and the pointer, by mutation. Doc-mass stays at 1500/1500: the exception's three lines in `foreman.md` are paid by three pure re-wraps.

## 6.31.1 — 2026-09-02

The launcher reads the answer the protocol taught the foreman to write. Field case, phase 10 of the same gnrwork run, under 6.30.1: the foreman answered the consult four minutes in with `plan-defect: apply` — the reply-path spelling `refs/foreman.md` gives — while the launcher's `case` matched the bare verb alone; the file was consumed, the unknown token fell into the default branch, which printed "No foreman answer within 600s" (neither half true), and a fable repair was launched on a phase the foreman was applying at that very moment. The repair found no `[!]`, had its one Edit refused under the landing commit and left cleanly; the `green` outcome the foreman then wrote was never read, and the run's inspection note blamed a launch-before-consume race that never happened. Two fixes. The launcher strips the `plan-defect:` prefix and lower-cases the answer, so both spellings are one answer; an answer it still does not understand is reported by name with the three expected verbs and the hold goes on — under 6.31.0's open-ended hold a fall-through would have sent an unread answer straight to repair, the exact thing that release removed. `/run-workflow` says both spellings are read. S43 gains the reply-path answer honoured as the verb, and an unknown answer reported, held through and followed by a real one; the static guard pins both.

## 6.31.0 — 2026-09-02

The plan-defect consult holds until a human answers, and a repair may not buy a green the plan never paid for. Field case, the 7-location-hours-calendar run on gnrwork: Phase 6 closed `[!]` at 00:10 with a TRUE claim — its contract test imported a table resource by a dotted path GenroPy never resolves — the foreman verified it on the code within minutes, the user was asleep, and at 00:20 the 600-second window handed the claim to the repair. The fable repair followed the skill's letter: it satisfied the contract AS WRITTEN by adding a `lib/resources/__init__.py` `__path__` shim in two packages so the import resolved, deleted the correct `py_requires` component the failed phase had built, recorded its own verifier's JUDGMENT (the shim bypasses the resource override chain) as a `> Review:` and closed `[x]`; Phase 7 read the green as legitimate; the morning cost one revert. Three changes. The launcher's consult has no deadline — holding costs nothing, the wrong repair cost a session and a revert — with `RUN_WORKFLOW_CONSULT_TIMEOUT=<seconds>` kept as the explicit opt-in and a stop request during the hold ending the run cleanly, the phase still `[!]`. While it holds, `/run-workflow`'s inspector CHECKS the claim against the code the `> Issue:` names, and the foreman's question carries that verdict with the recommended option following it — apply when the check confirmed a claim carrying its before→after edit, repair when it did not; the human still decides, a verified check being evidence put before them, never an answer written in their place. And `/repair-phase` gains a cost bound: a green that needs surface outside the phase's `Files:` and the failed phase's `> Files:`, or that its verifier flags as a JUDGMENT against the contract's own premise, confirms the claim at a price instead of dissolving it — the repair ends `[!]` with `> Repair attempted: plan-defect confirmed`, the workaround described in the note and reset out of the tree. The "both claims were wrong" prior that primed the foreman, the launcher and the repair towards disbelief now reads two wrong, one right, in all four places; `/write-workflow` checks every import path and fixture a contract test leans on against the repo before the plan commit — the thirty-second grep that would have caught this one at planning; S43 pins the open-ended hold, the stop request during it and the guard against a default deadline creeping back, by mutation. `docs/design-notes.md` → *The consult has no deadline* carries the rationale.

## 6.30.1 — 2026-09-01

The channel question comes after the mode answer, never beside it. Seen on the first plan written under 6.30.0: `/write-workflow` batched *interactive or autonomous?* and *where do decisions travel?* into one `AskUserQuestion`, so the channel was asked of a user who had just answered `Autonomous` — a mode on which `relayed` is the only legal value and the skill itself says the question is not asked. Harmless in outcome, one redundant question in cost, and exactly the ceremony-without-a-consumer #22 was about. Step 2 now says on the same line that the second question is put only once the first is answered and never in the same `AskUserQuestion` — same line, because `/write-workflow`'s closure sits at 1500 of its 1500-line doc-mass budget and the fix could not buy a line.

## 6.30.0 — 2026-09-01

The plan says where its decisions travel, and an attended workflow stops paying for a relay nobody consumes. Measured on one real run ([#22](https://github.com/fporcari/claude-phased-workflow/issues/22)): a 10-phase interactive plan cost 11 chats, ~35 cross-session messages, ~25 apparatus commits against 10 phase commits and nine `clarify?` rounds of five legs each — with the user at every gate anyway, so the foreman removed nobody from the loop and inserted a hop in the middle of one already closed; almost every clarify repaired a plan written before the code was read. Two optional fields and no others. `Channel:` in the header: `in-chat` runs the whole workflow in one conversation, every gate here, no `foreman.json`, no message, `refs/foreman.md` never loaded — 453 closure lines off `/execute-phase` and `/close-phase`, arriving as a doc-mass test failure rather than a claim; `relayed` keeps today's chat-per-phase protocol unchanged. `> Batches:` per phase: the existing `partial` commit promoted from escape hatch to planned subdivision, so a coherent phase whose diff is too large to read as one unit stays ONE phase with ONE `Done:` and ONE close — and, unlike a checkpoint, writes no `> WIP:` note, because nothing is stopping. `Mode:` keeps its meaning; a plan carrying no `Channel:` behaves exactly as before, unrewritten and uninterpreted; `autonomous` with `in-chat` fails validation, and so does `Chanel:` — the one field whose absence is meaningful must not be misspelt into legacy. The fork lives once, in `refs/phase-execution.md` → *Routing a decision*: a question, an outcome and a re-planning each take the road the plan names; the decision record in `notes.md` is owed on both roads, the message on `relayed` alone, and no channel waives a gate — the close still blocks on a divergence no covering decision records, wherever it was taken. Planning changes with it: phases are sized on decision boundaries, never file counts; `/scope-workflow` and `/write-workflow` look before they ask, against the four defect classes the run's ledger actually produced — a literal never grepped for duplicates, a behaviour transcribed from a design doc the code contradicts, a remedy unchecked against the tool's real flags, arithmetic never computed — and `Files:`/`Decisions:` assert nothing about code nobody has opened. Deliberately NOT the issue's "no plugin" tier: the artifacts it lists as paying at every size — the tracked plan, a re-runnable `Done:`, one phase commit per phase — stay on every channel, and only the apparatus switches off. S56–S60 pin it by mutation: the covering-decision gate holds on both channels and carries no channel condition, authored-check ownership is a position and not a chat, a planned batch is not an interrupted phase, recon precedes the questions, and every entrance forks with two different effects. `docs/design-notes.md` → *Phase sizing* carries the rationale and the corrections the implementation forced on it. What the release owes the field is one measurement: the first attended run on `Channel: in-chat` coming out as a handful of phases without the nine rounds.

## 6.29.0 — 2026-08-28

A *Done* tab, so the plan list is the plan being worked. Reported from the field on a repository carrying eight finalized workflows in `.phased/done/`: the list showed the active plan followed by every one of them, and the archive drowned the only row anybody was looking at. The rule for what moves out is the reporter's own, and it is sharper than "hide what is finished" — a macro-phase whose parent roadmap is gone has lost its meaning, so the workflows of past roadmaps are archive, while the macro-phases the CURRENT roadmap declares stay in *Plan* when they close, that sequence being what the roadmap shows. The tab appears only when there is an archive to open, its rows stay clickable into the Phase pane, and the last archived workflow leaving under an open tab falls back to *Plan* rather than drawing an empty grid. `test_done_tab.py` pins the partition against `build_tree` and pins the page to the same predicate; 34 tests in `tests/wfdash/`. What this release does NOT fix is the level the report exposed underneath: nothing records which roadmap a plan belonged to — the only link is the number inside the directory name — so a finished workflow of a past project whose number collides with a macro-phase of the current roadmap is adopted by it and reads as closed work nobody ever did. That is a design question, filed on its own.

## 6.28.8 — 2026-08-28

The plan pane shows the plan that is on disk. `/api/plantext` and `/api/roadmap` are read once per key and kept for the life of the page — the files change rarely and re-reading them every five seconds would fight whoever is reading the pane — but nothing ever dropped a copy, so a plan rewritten under an open pane went on showing the words it had been opened with, next to a row the tick had already moved to the new ones. Reported from the field on a plan whose phases had just been rewritten, and read as a dashboard that disagrees with itself: only a reload put the two halves back together. `state()` now carries the mtime of every plan text the page can show (`stamps`), the page remembers which mtime each cached copy was cut from, and a copy whose own has moved is re-read — once, on the next tick, with the stale text left on screen until the new one lands, because a blink back to `loading…` on every save is worse than a text one poll behind. A plan read out of a `wf/` branch carries no mtime and keeps the old behaviour, git having no rewrite for it. `test_plan_text_freshness.py` pins the stamps, the rewrite that moves exactly one of them, and the page's own comparison; 33 tests in `tests/wfdash/`.

## 6.28.7 — 2026-08-28

The page and the stamp answer from one resolution. `owner_stamp` compared the whole validated identity, but `/api/sessions` took only the pid out of it and resolved that: with a pid recycled by another chat on the same repository, the page named the NEW chat the dashboard's owner and offered to queue for it, while the stamp had already ruled it a stranger and was leaving the press unowned — reproduced as `sessions()['owner']` naming `s-new` against `owner_stamp() == {}`. One `live_owner()` now: it reads the identity once, resolves the pid, and returns the target only when the session id is the one that was validated; both callers go through it, so the page cannot promise what the queue will not record. The wfdash fixtures stop cherry-picking handler methods and subclass the handler itself — three releases running, a method growing a helper broke six of them at once.

## 6.28.6 — 2026-08-28

The owner is one value, and the queue's pre-upgrade events have a road of their own. `(pid, session id)` lived in two class attributes, and this server is threaded: a re-own landing between the two stores would be read as a mixed pair — one chat's pid with another's session, an identity that never existed — and `owner_stamp` re-read the attributes four times per press. One immutable `owner_identity` tuple now, copied into a local once by every reader. And the skill's leftover check assumed every event carries `owner_session`: on an event queued before 6.28.4 the prescribed command has no third argument to pass and dies with `IndexError` in the model's hands. The clause is written down — no `owner_session` means the old pid-only check and a recovery with `--pid` alone — together with the limit it carries: on a legacy event a recycled pid cannot be told from the chat that pressed, so `live` there means some chat holds that pid on this repository, not that it is the one waiting.

## 6.28.5 — 2026-08-28

The owner of a queued request is a whole identity now, kept where it was validated, and an orphan whose pid was recycled can be recovered at all. 6.28.4 stamped the pair but re-derived it at press time, so a record briefly unreadable — or a chat that had died since — silently downgraded the stamp to the pid alone, the very check the pair exists to strengthen. `/api/owner` and `-O` keep `(pid, session id)` together and refuse a pid whose record names no session; the stamp reads the cached pair and, when it no longer matches a live record, stamps NOTHING rather than attributing a press to a chat that is gone — an unowned event is one any chat may serve, which is where an ownerless press always belonged. The leftover check in `/wf:dashboard` compares session ids, not pids: a recycled pid resolves to a live session that never pressed the button, and matching the pid alone reported a dead owner as live and left its request queued for ever. And the recovery it prescribes needs the dead chat's own identity — `outbox.py --drain --pid <owner> --session <owner_session>`, both read off the event — because resolving the pid answers with the living session and rightly refuses the dead one's event. `test_recycled_pid.py` runs the whole story end to end against the real CLI: s-old presses, dies, s-new inherits the pid, gets nothing, reads `orphan` from the pair, and recovers the request explicitly, once.

## 6.28.4 — 2026-08-28

A queued request now names its owner by the pair (pid, session id), and a copied dashboard link explains itself. The pid alone never identified a chat: the system recycles pids, and a new Claude session on the same repository passed the owner check a dead chat's request was stamped with — the cwd comparison cannot tell two sessions apart. The server stamps the session id beside the pid, `--drain --pid` resolves its own through the server's `inbox.owner_target` and serves a stamped event only to the session that pressed it; a caller that cannot name its session (a test, a hand-run drain) keeps the old pid-only guarantee rather than being stranded. The second fix is a field report: the dashboard URL copied out of the preview pane into a real browser answered `{"error": "not authenticated"}` and read as a broken dashboard. It was correct — the `?k=` authenticates one load and the cookie replacing it belongs to one browser — but nothing said so. The page path now answers that refusal in prose, with the way back in (`/wf:dashboard`, or `server.py --probe`), naming neither the port nor the repository; the API paths keep their JSON, their callers being machines. `/wf:dashboard` and `docs/wfdash.md` say the link is one load in one browser, and that a second window is a fresh `--probe` rather than a second server.

## 6.28.3 — 2026-08-28

Two findings against 6.28.2's own queue work. Recovering an orphaned request was prescribed as a bare `--drain`, which takes the WHOLE queue — a third chat's pending request included, and that chat is still going to ask for it: the recovery is `--drain --pid <the orphan's pid>`, which takes the dead owner's share and nothing else. And the filtered drain's two halves were not one transaction: `served` came from the drain, `remaining` from a `read()` that took a second lock, so an append landing between them was reported as an event the drain had declined — exactly the disagreement the skill's prose promised was impossible. `drain_split` now partitions inside the drain's own lock and `drain` is a thin caller of it; `remaining` is what THIS drain left behind, never a later reading of the queue.

## 6.28.2 — 2026-08-27

Three findings from the review of 6.28.1, the first of them a collision that predates the dashboard entirely. Every control file of a run — the stop request, the consult answer, the apply outcome, the run log — was named from the slug alone inside one per-uid directory, so two checkouts carrying the same plan read and CONSUMED each other's signals: a root and the worktree the launcher itself creates for it, or simply two clones. Reproduced by running the bash and zsh suites at once, which took S49 down on both. `next-phase.py --transport` now owns the naming — `<TMPDIR>/phased-workflow-<uid>/<slug>-<repo key>` — and the launcher, `/run-workflow` and `/resume-workflow` all ask it for the same prefix instead of each spelling one out; S55 pins that two checkouts sharing a slug get two prefixes, that the prefix is stable across calls, and that `next-phase.py` and `wfdash/outbox.py` name one directory in their two languages. The filtered drain, second finding, told the chat to name what it left behind while handing back only what it took: `--drain --pid` answers with both halves now, `served` and `remaining`, read under the same lock so the two cannot disagree — and the liveness check the skill prescribes for an orphaned event is the server's own `inbox.owner_target` (session record plus cwd), not `ps -p`, which proves only that some process holds the pid. Third, the `drain` docstring still described the read as happening after the lock was released, which stopped being true when the write-back arrived in 6.28.1.

## 6.28.1 — 2026-08-27

Four findings from the review of 6.28.0, three of them holes in what that release had just built. The contract-field extractor matched `Pattern:` only, while the autonomous plan template writes `Pattern reference:` — so on exactly the plans the launcher runs, the pattern reference fell out of the close's gate the day the gate was written; both spellings are accepted now (unifying the templates would orphan the plans already in the field) and S52 asserts the extraction against the rendered template itself, not a retyped fixture. The shell side of the transport still created it with `mkdir -p`: under umask 022 the directory is born 0755, and on a run with no dashboard the shell gets there first — the launcher's consult path and the skill's tee snippet now use `install -d -m 700`, which also tightens a directory an older release left lax, asserted live in S49 and pinned as an idiom by S54. The close's plan commit was searched with `git log --all`, which can answer with another workflow's commit when a slug was reused on another branch: it searches HEAD's own history, where the plan commit is by construction an ancestor, and an empty result blocks the close instead of diffing against nothing. And the re-own of a reused dashboard reached `Handler.owner_pid` and stopped there — the queue was one anonymous file per repository, so any chat draining it consumed a request pressed for another chat's context. Events now carry the owner stamped at append time, `outbox.py --drain --pid` takes only this chat's share plus the unowned events, and the skill says what to do with what stays queued: name whose it is, or drain it as an orphan when that pid is no longer a live session on this repository. Deliberately not a hard filter — an orphan queue that nobody may drain is a button dead for good.

## 6.28.0 — 2026-08-27

Five findings from an external review of 6.27.0, each a promise the code did not keep. The contract-field protection was declared and not implemented: `refs/foreman.md` said the close diffs the phase block against the plan commit, and the close diffed only `tests/phase-N/` — `next-phase.py --contract-block N` now extracts the foreman-owned field lines of one phase (`Done:`, authored `Verify:`, `Pattern:`, `Files:`, `Decisions:`, continuations attached, `>` notes excluded) and `/close-phase` diffs the extraction at the plan commit against HEAD, blocking on a divergence no foreman decision in `notes.md` covers; S35 pins both the citation and the extraction itself. The `contract tests ⇒ no light phases` invariant was a NOTE inside a run already launched, which protects nothing: the pre-flight now refuses the combination before the first session is spent, with `RUN_WORKFLOW_ALLOW_LIGHT_CONTRACTS=1` as the explicit, deterministic override (S53 rewritten — refusal, override, zero sessions). A reused dashboard server stayed owned by the chat that first started it while the skill promised the page's commands come back "to this chat": `--probe -O` re-points the owner through the authenticated `/api/owner`, whose pid must resolve to a live session record on this repository — the same check `-O` always got — so the owner is the LAST opener, the chat the person is actually talking to. The transport under `${TMPDIR:-/tmp}` is namespaced by uid — `phased-workflow-$(id -u)`, the same computation in bash and python — because a fixed `/tmp/phased-workflow` at 0700 meant the first user on a shared host locked every other user out of stop requests, consult answers and queues alike. And the perimeter's threat model is stated exactly instead of strongly: with the token in an owner-only registry file, the barrier keeps out other machines, other UNIX users and the browser's other pages — never another process of the same user, which could always read the transcripts; `docs/wfdash.md` and the server's own comments now say so. The doc-mass budget is paid, not raised: `close-phase`'s closure is compressed back under its 1500-line ceiling.

## 6.27.0 — 2026-08-27

The eleven field lessons the ledger had queued are consumed, most of them from the tmsh-simple-availability and wfdash-open-findings runs. Two collisions that cost gate corrections enter `/write-workflow`'s Decisions step: when two phases read and write the same table's UI surface, the row-set boundary between them is settled explicitly — who lists what, who excludes whose rows — instead of each phase's surface being settled in isolation; and on a `ui` phase, layout composition is recorded as mockup-negotiable intent rather than a fixed Decision, because freezing it before any visual turned the user's own gate judgment into a plan contradiction. `/scope-workflow`'s decision tree gains what a surface must REFUSE, and at which layer — a whole validation requirement had surfaced only as the third clarify of a phase — and the instruction to phrase a mode or tier question at the deployment level (*who ever sees both?*) before choosing between UI treatments that only exist in the mixed case. Contract tests get four fixes. They are LINTED at authoring, before the plan commit: a `Done:` demanding a clean lint on the copied test and a contract copy that must stay byte-identical are one requirement, and a test failing the lint forces every phase carrying it to break one of the two. The close now diffs the plan copy against the plan commit as well as the in-tree copy against the plan copy — a child that edits BOTH copies makes them agree, so byte-identity alone could not see it rewriting its own contract, and one did. A phase chat's licence to edit its own plan block stops at the contract fields (`Done:`, authored `Verify:`, `Pattern:`, `Files:`, `Decisions:`): additions ride `>` lines, and a run watched one of them delete foreman-owned fields undetected. And a plan carrying contract tests may not have `low` phases at all: `low` runs in light mode, which ships no contract doctrine, and the measured correlation is exact — the three light phases all edited their contract test, the two full-mode ones never touched it. The launcher says so in its pre-flight, naming the phases (S53, live and static, proven by mutation). The autonomous plan template's final config row read `| Phase N+1 (review) |`, which `--validate` rejects: a plan written exactly to the shipped template failed the launcher's own gate. The row carries the number alone, and S52 renders the template and validates it so the two cannot drift apart again. On the foreman channel, a decision's full text — plan edits included — belongs on disk at road 1 and the reply may just point at it: the channel was seen accepting a message and taking minutes to arrive, so a child re-reads `notes.md` before waiting on it, and a plan change sent mid-phase asks for receipt confirmation, so a late batch cannot execute an instruction already superseded. Finally the closing report page is handed over with `SendUserFile` and `display: render` explicitly: the page lives outside the repo by design, and a client left to choose attaches exactly such a file as a download card, which is what the field run got. NOTE for whoever adds doctrine next: `close-phase`'s closure now sits at 1500 of its 1500-line budget — S41 fails on the next line added to `common.md`, `contracts.md`, `foreman.md`, `naming-review.md` or `phase-execution.md`.

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
