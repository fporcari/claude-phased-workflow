# 6.5.0 — a phase that outgrew its chat closes on what it reached

6.4.0 answered the long phase with a handover: checkpoint, write down what
four keys cannot hold, stop, let a new chat pick it up. It works, and it is
the second-best answer.

**A phase that does not fit in one context was sized wrong** — the plan's own
doctrine, turned on itself. Carrying half-cooked state across a chat boundary
preserves the mis-sizing; the plan goes on claiming a phase is in progress,
the tree stays dirty with `partial` commits, and the naming markers wait. The
honest response is to end the phase on what it actually built and let the plan
learn that the slice was too big.

So the first question is no longer *how do I carry this over* but **is there a
seam here**:

- **A coherent, demonstrable sub-result, and what exists is green** → **close
  short**. The phase ends properly, the tree is clean, the markers are
  reviewed, and the plan grows a phase for the remainder.
- **Work in mid-air** — a refactor half applied, a schema nothing uses yet —
  → **hand over**, 6.4.0's mechanism. There is no honest `Done:` to write.

## Closing short

The obstacle was never the mechanism, it was `[x]`: it promises the `Done:`
passed, and on an overrun phase it has not. The answer is not a sixth marker
but a correction: **the phase's `Done:` is rewritten to the sub-result
actually reached**, and its `Files:` to what actually landed, with the user's
ok. Mid-phase the child is the only writer of the plan, so it makes that edit
itself — on its own phase, never on the others. A narrowed `Done:` is not a
lowered bar; it is the plan corrected to match what was built, which is the
precondition for `[x]` to keep meaning what it says.

Then it is an ordinary close: naming review, `Done:` gate re-run — it passes
now, honestly — `[x]`, one phase commit. The foreman gets a line of its own:

```
[wf:<slug>] phase N closed short — <what landed>. Remaining: <one line>; it needs a phase of its own.
```

and the remainder also goes to `notes.md` under the phase's heading, because a
remainder that lives only in a message dies with the message.
`/resume-workflow` writes the phase (or phases) that carry it — never the
child: sizing is the foreman's job, and a phase that overran is evidence about
the sizing, not only about itself.

## The refusal stays where it belongs

`/close-phase` still refuses a red criterion — a failing test, a lint error —
and always will: that is repair territory, never absorbed at close. What
changes is the case it used to lump in with it: a criterion **unreached**
because the phase never got there, with everything it did build green, is the
closed-short case. The skill now says which criteria are unreached, proposes
the narrowed `Done:`, and closes on the user's ok.

## The guards

S30 gains four checks — the fork lives in the shared core, `common.md` carries
the `closed short` line, `/close-phase` distinguishes red from unreached, and
`/resume-workflow` owns the remainder — plus a mutation that removes the fork
and leaves an overrun phase with nowhere to go.
