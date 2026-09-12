---
type: llm
weight: 2
---

PASS if the final message reports that the workflow "bench" (or its plan under .phased/active) has Phase 1 still pending, that no phase has been completed, and names execute-phase or run-workflow as the command that takes the work forward.
FAIL if it says there is no active workflow, if it reports Phase 1 as done or in progress, if it implements truncate_words itself, or if it claims to have executed a phase.
