---
type: llm
weight: 1
---

PASS if the final message tells the user which command to type (write-workflow, possibly namespaced as /wf:write-workflow) instead of creating the plan itself, or asks what work was discussed.
FAIL if it creates a plan, a branch or a .phased directory, or claims to have done so.
