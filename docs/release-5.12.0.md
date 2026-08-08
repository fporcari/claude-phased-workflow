# 5.12.0 — the `ui` tag: mockup gate, browser pass, and the ui-judge

Interactive mode is where UI work lives — `/write-workflow` itself recommends
it for "anything whose success is *I'll know it when I see it*" — yet nothing
in the flow ever showed the user anything to see before the code existed. The
approval gate described a UI in prose, the phase built it, and the first
visual judgment happened on the finished page: too late to steer, and the
finished pages showed it. This release makes the *look* a first-class
contract, negotiated before a line of source is written and checked against
the result by fresh eyes.

## The `ui` tag

A third phase tag next to `vast`: a phase whose deliverable is judged by eye —
a page, a form, a dashboard. Decided at planning like the others (it changes
execution, so it is batched into the Decisions questions), and confined to
interactive plans: an autonomous run has nobody to approve a mockup.

## The mockup gate

In `/execute-phase`, a `ui` phase extends Step 3: before asking for approval,
the chat builds a throwaway **static HTML mockup** — look and layout only,
plausible fake data, no framework — and shows it rendered. This gate may
loop, mockup → feedback → mockup, as long as it takes: aesthetics is all
decision, and a decision is the one interruption the skill has always
considered legitimate. A text description is never a substitute.

Approval of the phase IS approval of the mockup. The approved version is
saved as `mockups/phase-N.html` in the plan directory and rides the phase
commit: it is the phase's **visual contract**, and it survives the chat that
negotiated it.

## Browser verification, and who logs in

`common.md` → *Verification* gains the generic rule: before driving any
browser check, establish whether the target is login-gated — and when it is,
the **human operator performs the login, always**. The executing agent never
types, logs, or persists credentials, whatever impersonation convention the
project offers. Project-specific login lore (GenroPy's passpartout
convention, its discovery query) stays where it belongs: in the separately
shipped `ui-test` skill and the shared knowledge base — zero framework
specifics inside this plugin.

The `ui-test` skill itself (not part of this plugin) was refocused in step:
site autodetection instead of an interrogation, login established first and
always handed over, and a second deliverable next to the functional verdict —
screenshots of the key states, saved beside the reference mockup.

## The ui-judge

A new agent closes the loop, modeled on `phase-verifier` and sharing its
finding grammar: **`ui-judge`**, a fresh-context, read-only subagent that
receives the approved mockup, the screenshots of the real page, and a
one-line brief — and nothing else. The author of a UI is the worst judge of
its own fidelity; the judge has not seen the conversation and compares
contract against result: completeness, structure, legibility. `MECHANICAL`
findings (an element missing or plainly wrong versus the mockup) are fixed on
the spot; `JUDGMENT` ones (a deviation that may be legitimate, an aesthetic
call) land in `> Review:` and never block. Taste beyond the mockup remains
the human's, on the `Verify:` list.

A `ui` phase that reaches `/execute-phase-agent` anyway — an imported plan,
a mode change — degrades explicitly, not silently: no mockup gate and no
browser pass exist unattended, so the visual check is handed to the human as
a `Verify: now` step.

## Tests

Markdown-only release; the orchestration suite guards the cross-references
and picked the new sections up unchanged. 187 assertions over 29 scenarios,
green.
