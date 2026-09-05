# Execution policy — shape, roles, budget

The one place that says how much machinery a job deserves. Skills cite it (`/scope-workflow`, `/write-workflow`, `/import-workflow`, `/quality-check`); none restates it. Everything here is advice the human can overrule — the launcher enforces only what it names (`run-workflow/SKILL.md` → *Bounds*).

## The delivery shape comes before mode and channel

Recon is bounded to the facts needed to choose. Weigh design, implementation, context reloads, coordination, verification and the corrections likely to follow; never book a saving nobody measured.

| Shape | Choose when |
|---|---|
| **One chat** | One coherent result fits one context with room for diagnosis and verification, and no intermediate result changes what comes next. Hard coupled bugs often fit. No workflow interview, no `.phased/`: `/write-workflow` hands over the one-chat brief. |
| **One durable phase** | The same coherent result must run unattended, survive a restart, or be handed over — a plan of one phase, with checkpoints and repair. The quality check is not a second implementation phase. |
| **Several phases** | An intermediate result changes the next decision, the work does not fit one context safely, or independently testable deliveries justify the handoff. Every seam names its evidence and its consumer. |
| **Macro-phases** | A usable capability, a compatible migration or an accepted interface informs later planning. Detail only the next ready macro; the rest keep their itinerary and contracts in `.phased/roadmap.md` (`write-workflow-autonomous.md` → *Macro-phases*). |

File counts and phase counts are warnings, never cutoffs. Tests stay with the implementation they prove. Broad coherent edits are one phase with `> Batches:`; a boundary whose only effect is re-reading the same code is merged away.

## Responsibilities, not obligatory sessions

| Role | Owns | Gets a session of its own when |
|---|---|---|
| Engineer | Design, contracts, diagnosis, the hard implementation | A premise is unknown, behaviours are coupled, or a wrong guess is costly to reverse |
| Worker | A decided, bounded change with a pattern and a measurable `Done:` | Tests tell success from failure and no design decision is delegated |
| Foreman | Ownership, sequencing, budget, evidence, escalation | Never for routine state — tools carry it; the foreman decides |
| Reviewer | Independent behaviour, contract and integration checks | Non-trivial implementation; depth follows risk |

Four roles do not mean four sessions: a compact job's engineer finishes it. Exact transformations go to tools, not to a model. `fable` up front for architecture, coupled diagnosis, hard implementation or material re-planning — one fable engineer is often cheaper than opus plus the handoffs around it; `opus` for decided work and routine review; `low`/`medium` effort for decided work, `high` for unknowns, higher only with evidence. Every effort level runs the same contract — effort is reasoning depth, never a lighter doctrine. Record the model, effort and reason where the plan already has a place for them (the execution config table, `notes.md`); an unavailable model is reported, never silently substituted.

## Correction, review and budget

- **In a phase**: the bounded attempts the executing skill states (two, with the no-progress detector — the same failure signature twice ends guessing, a missing premise ends it at once), then `[!]` with the evidence for repair. ONE fresh-eyes repair may follow; a failed repair stops the run. Relaunching or changing model never resets the count — `RUN_WORKFLOW_MAX_ATTEMPTS` is the hard boundary, and a hard boundary leaves a checkpoint, never a half-applied edit.
- **At the close**: `/quality-check` collects the QA, naming and review findings at ONE revision, groups them by root cause, applies ONE approved batch and verifies that batch once over its delta and consumers. No corrective phase per finding, no second whole-diff hunt over unchanged scope; a residual defect is a reported decision, not a fresh round. Panel means one reviewer plus at most one specialist for a visible distinct risk — evidence settles disagreement, not votes. `/pull-request` reuses that coverage and reviews the delta.
- **Budgets** stay separate: implementation, review and repair each have their own; a consult hold keeps human authority and costs nothing. The launcher's dollar caps are runaway nets, not spend limits — on a subscription, usage is not an invoice, and unknown usage is reported as unknown, never as zero.
