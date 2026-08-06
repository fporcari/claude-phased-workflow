# 5.9.0 — a skill that waits says so

A real `/write-workflow` run ended its plan presentation with

```
Branch: sei su develop → creo wf/273-genro-storage-handler   (dimmi se preferisci diversamente)
```

and stopped. Behaviorally correct — Step 4 says *only after approval* — but nothing
told the user a reply was expected, or what saying "ok" would unlock. Read cold,
"creo" is both an announcement and a conditional, and the code fence makes the line
look like log output rather than a question. Only someone who knows the flow by
heart guesses that the skill is waiting.

An audit of the whole chain found the same defect in six more places: gates that
exist in the rules ("get approval", "get explicit confirmation", "wait for the user
to confirm") but are invisible in the prescribed output. The chain was lean; it just
never said out loud where it stops.

## The gate line

`common.md` gains the shared convention every skill now cites instead of improvising:

> **Procedo?** Al tuo ok \<exactly what happens next\>.

One line, plain text, **never inside a code fence**. The verb can change
(*Confermi?* / *Lancio?*), the shape cannot: a bold one-word question, then what the
ok unlocks. Multi-way choices keep going through `AskUserQuestion`; the gate line is
for the binary "go" that unblocks the skill.

Applied where a presentation ends in a wait:

| Skill | The gate, now visible |
|---|---|
| `/write-workflow` | branch line + *"**Procedo?** Al tuo ok creo il branch e scrivo `.phased/active/<slug>/plan.md`."* |
| `/scope-workflow` | *"**Confermi?** Al tuo ok qui è finito: lancia `/write-workflow` in questa chat."* |
| `/import-workflow` | *"**Procedo?** Al tuo ok creo/adotto il branch e committo il piano."* |
| `/run-workflow` | *"**Lancio?** Al tuo ok parte il run in background su tutte le \<N\> fasi."* (no AskUserQuestion in its tools — the line is the gate) |

## One gate, not two

`/finalize-workflow` Step 7 stacked two approvals: first the commit message
(default yes), then "Come vuoi procedere?" — the latter specified as a fenced
checkbox list, the same reads-as-log defect. Now it is ONE `AskUserQuestion`
(Pull request recommended / Merge sul parent / Solo commit); choosing a path
approves the message as shown, and edits to it are invited right above the question.

## No fake questions

`/issue` closed by asking *"Vuoi che proceda con `/write-workflow`?"* — and answered
a yes with "run it yourself": the skill cannot invoke `/write-workflow`, so the
question promised something it cannot do. It now closes flat: *"Prossimo passo:
lancia `/write-workflow` per creare il piano."*

## The close always names the next step

`/execute-phase` ended its summary with what was done and the manual checks — and
nothing else. Whoever finishes phase 2 of 5 had to know by heart that the flow
continues with a new chat and `/execute-phase`. The summary now always ends with the
next step: the next phase with its `Run:` hint quoted, or `/finalize-workflow` when
it was the last — matching what `/write-workflow` and `/resume-workflow` already did.
