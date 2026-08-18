# 6.2.0 — the board becomes a strip you read

The board was a working view: a card per phase carrying a status picker the
user drove, a remarks box, and a button that exported the remarks as a prompt
for a fresh chat. It was designed in 5.6.0–5.7.0, when the chats of a workflow
could not talk to each other and a widget was the only place to put a remark.

They talk now. A phase chat reports upward, asks the foreman a `clarify?`, and
since 6.1.0 hands its checks back to the human and waits. A remark typed into
a textarea competes with a conversation that keeps what it is told, carries it
to the plan and to the foreman, and can be argued with — and it loses: the
controls lived in one message and died with it, while everything around them
became persistent.

So the board is now what it was always read as: **one strip, one row per
phase, the marker as the plan has it, the next phase picked out.** A header
line (`done N / M`, branch, mode), the `Run:` hint beside the next row, and
the launch command once underneath as text. Nothing on it is clickable.

Gone with the controls: the per-card status pickers and their ordering rules,
the remarks boxes, the export prompt and its scaffold, the per-card commands
and the `copy command` gating. `/resume-workflow` no longer points the user at
a textarea for the *"this phase passed and is still wrong"* case — it asks
them, which is what the case always needed. `board.md` drops from 150 lines to
55.

What stays is the reasoning that keeps it read-only: `sendPrompt` writes into
the chat you are in, so a run button would execute a phase in the supervision
chat; a refresh button could only re-run the skill and print a second report;
a `spawn_task` chip forks a worktree the plan already has. Those three are why
the strip is a snapshot, not a console.

## The guard

S30 gains two checks: the board declares itself read-only, and neither the ref
nor any skill specifies a control — a positive and a negative, so the shape
cannot drift back one card at a time.
