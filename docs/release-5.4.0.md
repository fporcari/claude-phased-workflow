# 5.4.0 — invocation discipline, and `/scope-workflow`

Two changes, from an audit of how the plugin's own skills are written: they stop
being reachable by the model when only a human should reach them, and the
interrogation step that was missing in front of `/write-workflow` now exists.

## 1. Invocation: 9 of 12 skills are now user-invoked

A skill with a `description` in its frontmatter is **model-invoked**: the agent can
fire it on its own, and its description sits in the context window of every session
in every repository where the plugin is installed. A skill with
`disable-model-invocation: true` is **user-invoked**: only a typed `/name` reaches it.

All eleven shipped skills used to be model-invoked. Nine are typed by hand, so nine
are now user-invoked.

**The reason is control, not tokens.** The token saving is noise — roughly 190
tokens per turn from the description list, on a 200k window, in a cached system
prompt. What mattered: `/write-workflow` creates a branch and commits, and
`/finalize-workflow` rewrites history with a squash. Model-invoked, either could
fire off a passing remark in conversation — *"ok allora facciamo così, prima il
modello poi la UI"* — with no typed command and no approval gate, since launching a
skill is not itself a permissioned action.

Three stay model-invoked, each for a concrete reason:

| Skill | Why it must stay reachable by the model |
|---|---|
| `execute-phase-agent` | `run-workflow.sh:163` reaches it from inside a `/goal` contract whose body is prose — *"Use the execute-phase-agent skill…"*. That is model invocation. |
| `repair-phase` | Same, via `REPAIR_PROMPT`. |
| `resume-workflow` | The entry point and router: the one skill the agent should reach on its own when the user asks where the work stands. |

Applying the switch across the board — the obvious move — would have broken the
autonomous chain silently on every CLI ≥ 2.1.139, since the `/goal` path reaches
those two skills by name in prose rather than by slash.

**What changes for you:** typing `/finalize-workflow` works as before; saying
*"finalizza il workflow"* in prose no longer fires it. The one prose trigger that
still works is *"dove siamo?"* → `resume-workflow`, which then names the command to
type. Launchers are unaffected: `claude -p "/phased-workflow:<skill>"` works fine on
a user-invoked skill (verified).

**`resume-workflow` is now the router.** It carries a `## The map` table naming all
the other skills and when to reach for each — the cure for the cognitive load of
user-invoked skills you have to remember on your own.

## 2. Design rationale out of the runtime

Skill bodies carried passages explaining *why* something is the way it is, or why
something is deliberately absent. The agent reads them at the start of every phase;
they change nothing about what it does.

They now live in [`docs/design-notes.md`](design-notes.md), which is never read at
runtime: the cost of the interactive phase boundary, why interactive plans carry no
execution config table, why adopting a feature branch is safe, why phase logs are
`.txt`, the thick/thin verification note, and the invocation reasoning above.

Add to that file whenever a skill is tempted to explain itself.

## 3. `refs/auto-mode-scope.md`

The auto-mode permission list was 30 lines inside `refs/common.md`, which eight
skills read at start — but only two consume that list (`/run-workflow` pre-flight
and `/write-workflow` on the autonomous branch). It moved to its own ref file,
cited by those two. `common.md`: 256 → 229 lines.

Correction to the first audit pass, which called this section a no-op: it is real
reference with real consumers. It needed disclosing one rung down, not deleting.

## 4. `/scope-workflow` — the interrogation before the plan

`/write-workflow` already requires every judgment call to be settled before
execution:

> *every choice needing the user's judgment — naming, signatures, library, API
> shape, trade-offs — is settled here … A phase containing "decide later" is not
> ready.*

Good rule, but it applies it by **reading the conversation**. When the conversation
was vague there is nothing to read: it either invents the decisions or writes phases
with "decide later", violating its own rule.

`/scope-workflow` fills that gap. It is user-invoked and produces **understanding
only** — no branch, no file, no code. The handoff costs nothing: `/write-workflow`
reads from the current conversation, so scoping in the same chat leaves the tree
already resolved in front of it.

```
/scope-workflow "gestione listini"  →  /write-workflow  →  /run-workflow or /execute-phase
        settles the decisions            records them          executes
```

Four properties do the work:

- **Every question fills a field of the plan.** `Mode:`, `Decisions:`, `Pattern:`,
  `Files:`, `Done:` — the skill knows which one before it asks, which makes the
  questions narrower than interrogating in the abstract. A branch with no field and
  no phase to land in is not settled.
- **The mode fork leads.** Interactive or autonomous reshapes everything below it:
  the same work splits into different phases under the two. Settling it first, with
  a recommendation derived from the work, means `/write-workflow` no longer
  rediscovers it at its own Step 2.
- **A fact is looked up, never asked.** What exists today, where it lives, who
  calls it — found with Grep/Read/`git log`/`gh issue view`, and reported with
  concrete paths so a wrong premise gets corrected before it costs a whole branch
  of questions. Only *decisions* go to the user, ordered by what they unlock: a
  decision that reshapes the ones below it comes first. A batch of questions cannot
  do that — it does not yet know which later question depends on which answer — and
  the tree grows during the interrogation rather than being fixed up front.
- **A close in the plan's own vocabulary.** Every branch ends **decided**, or
  deferred as a `Verify: deferred: needs Phase M`. *"Vediamo poi"* with no trigger
  does not count, the same standard by which `/write-workflow` rejects
  "decide later".

A pre-flight guards the entry: if a plan already resolves under `.phased/active/`,
scoping stops and points at `/resume-workflow` or `/execute-phase`. One branch, one
plan.

### Worked example

Starting point: you have "gestione listini prezzi" in your head and have never
decomposed it.

> **You:** `/scope-workflow` gestione listini prezzi per il pacchetto vendite

> **Claude** — Step 1, looks up rather than asks: reads `packages/vendite/model/`,
> finds `articolo.py` and `cliente.py`, no listino table, and a `prezzo` column on
> `articolo`.
>
> Trovato: `prezzo` è oggi una colonna su `articolo`, usata in 3 punti
> (`ordine_riga.py:88`, `fattura_riga.py:112`, `webpages/articolo.py:41`).
>
> **Domanda 1 — interattivo o autonomo?**
> Consiglio: **interattivo**. Motivo: c'è una UI di gestione listini da guardare, e
> "il form si legge bene" non è un test. Le fasi si chiuderanno dove esiste qualcosa
> di apribile.
> *(decide come si spezzano tutte le fasi — la faccio prima)*

> **You:** interattivo

> **Claude — Domanda 2 — il prezzo resta su `articolo` o si sposta sul listino?**
> Consiglio: **si sposta**, e `articolo.prezzo` diventa un alias deprecato che legge
> dal listino di default. Motivo: se resta, hai due fonti di verità e il primo bug è
> "quale vince".
> *(questa decide tutte quelle sul modello — la faccio prima)*

> **You:** si sposta

> **Claude — Domanda 3 — un listino per cliente, o listini condivisi con
> assegnazione?**
> Consiglio: **listini condivisi** (`listino` ↔ `cliente` many-to-one). Motivo: 200
> clienti con 3 fasce prezzo diventano 200 listini duplicati.

> **You:** condivisi, ma serve anche l'override sul singolo cliente

> **Claude:** Allora sono **due** meccanismi, e devo sapere quale vince.
> **Domanda 4 — validità temporale: la vuoi ora o dopo?**
> Consiglio: **ora**, ma solo su `listino` (date da/a), non sull'override. Motivo:
> aggiungerla dopo significa migrare le righe esistenti.
> *(se dici "dopo", la domanda 5 sull'indice di lookup cambia)*

Note what happened at Domanda 3: the answer opened ground that was not mapped
(two mechanisms, one precedence rule), so the tree grew a subtree. A parallel batch
of four questions could not have discovered that.

It closes on a recap in Italian — *Deciso / Rinviato / Fatti su cui poggia* — and
waits for you to confirm the shared understanding before anything else happens.

### Writing ADRs as it goes, not taken

A variant that writes ADRs and a glossary while it interrogates was considered and
skipped: the `Decisions:` field already on every phase is the same artifact, placed
where the executor actually reads it, and `/finalize-workflow` Step 5 already
captures the durable lessons. Decisions the interrogation cannot close because they
need eyes on something that does not exist yet have a home too — `Verify: deferred:
needs Phase M`.

## Companion, outside this repo

The same audit produced a personal output style at
`~/.claude/output-styles/asciutto.md` — deliver the scope asked, outcome first,
explanations as summaries by default, and end when the answer ends. It is not part
of the plugin: verbosity happens on every turn, so the fix belongs in the system
prompt, not in a skill you would have to invoke first.

The division of labour: `/scope-workflow` is discipline about **asking** (one question at a
time, recommendation included, facts looked up), `asciutto` is discipline about
**answering**. Siblings, deliberately not merged — inside `/scope-workflow` the terse style
would apply only during a scoping session, which is the one moment it is already terse.
