---
name: feedback-thoroughness-over-literal-instructions
description: When a task hands you a "confirmed exhaustive" list of resources/references to change, still re-derive it yourself — the given list can be incomplete
type: feedback
---

When a task description says a list was "already surveyed exhaustively" (e.g., "list of ~4 shared resources needing special treatment"), still re-verify it independently with your own grep before acting on it, and treat any discrepancy as something to fix consistently rather than silently working around.

**Why:** In the ADR-0012 state-key-separation task, the task description listed 4 resources needing cross-state remote-state treatment (Security Groups + subnet groups). Independently grepping all direct references inside the `*.staging` resource blocks turned up a 5th: `aws_docdb_cluster_parameter_group.this`, also referenced directly by the staging DocumentDB cluster but omitted from the task's list. Applying the literal 4-item list would have left a broken reference (`aws_docdb_cluster_parameter_group.this[0].name` unreachable from the staging-only state) that `terraform validate` might not have caught cleanly depending on how it was gated. Catching it required re-deriving the shared-resource list from the actual code rather than trusting the hand-off.

**How to apply:** For any implementation task with a pre-supplied "complete" list (resources to gate, references to fix, files to touch), run the equivalent grep/search yourself before starting, and again before declaring done. Report any additions found beyond the given list explicitly in the final summary/IMPL doc rather than quietly folding them in.
