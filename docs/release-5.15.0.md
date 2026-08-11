# 5.15.0 — the plugin stops choosing the language

Issue #8, opened against 5.13.0, said it plainly: the plugin shipped Italian
hardcoded in its prompts, and every user got it. Italian gate lines, Italian
question options, Italian board labels, whatever language they work in. For
something published as a plugin that is a defect, not a convention — it had
simply never been separated from the author's own setup.

The rule it rested on was one line in `refs/common.md`:

> All written content (plans, phase notes, code, comments, commits, PRs,
> issues) in English. Conversation with the user in Italian.

The first half is right and stays: the artifacts outlive the chat that wrote
them, and what reads them next is usually another session. The second half was
never the plugin's decision to make.

## The canon is English, the conversation is the user's

`common.md` now says so:

> **The conversation is in the user's language, never in one this plugin
> picks.** Follow their own configuration — global instructions, output style,
> or simply the language they are writing in. Every wording quoted below and in
> the skills (gate lines, question options, closing messages, board labels) is
> the English **canon of what to say**, not the language to say it in.

That distinction is what makes the rest mechanical. A skill that quotes a
wording is fixing *what* is communicated — the gate line's bold one-word
question and what the ok unlocks, the stop-work question's two options, the
closing message's four facts. The presentation layer speaks the user's
language. Nothing about the flow changes for a user who works in Italian; the
plugin just no longer imposes it on anyone else.

## What changed, concretely

| Where | Was | Is |
|---|---|---|
| gate line | **Procedo?** Al tuo ok … | **Proceed?** On your ok, … (*Confirm?* / *Launch?*) |
| stop-work question | *Fermo lavori* / *Continua* | *Stop workflow* / *Go on* |
| board states | `da fare` `in esecuzione` `fatta` `problema` | `to do` `running` `done` `problem` |
| board controls | `copia comando`, `annotazioni e problemi`, `esporta prompt correzioni` | `copy command`, `notes and problems`, `export fix prompt` |
| board export prompt | Italian scaffold | English scaffold; the notes inside stay the user's own words |
| foreman rename | *è l'indirizzo a cui le chat di fase mandano gli esiti* | *it is the address phase chats report to* |
| finalize's close-out | *Merge sul parent* / *Solo commit* | *Merge into parent* / *Commit only* |
| report detail question | *Espandi tutto / Scelgo io quali / Basta così* | *Expand all / Let me pick / That's enough* |

Thirteen files under `plugins/phased-workflow/`, plus the two skills whose
front matter used to state the Italian rule outright (`/issue`,
`/pull-request`) — they now cite `common.md` → *Language* like everything else.
`robottino`, the affectionate name for autonomous mode, goes with them: it read
as jargon to everyone who did not already know it.

S30's asserted wording follows the canon it guards, and the orchestration suite
is green at 198.

## Also in this release

The version drift guard had been failing on `main` since 5.14.0 —
`marketplace.json` was left at 5.11.0 while the README and `plugin.json` moved
on. Exactly the drift the guard exists to catch, and it caught it; nobody
looked. All three now agree, and CI is green again.
