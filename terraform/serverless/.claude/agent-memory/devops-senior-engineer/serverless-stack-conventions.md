---
name: serverless-stack-conventions
description: Conventions and backend/state facts specific to the `serverless` Terraform stack (devopsproject-ecommerce-iac)
type: project
---

**Backend/state facts for the `serverless` stack:**
- State bucket: `devopsproject-terraform-state-692430448478`, region `us-east-1`, key `serverless/terraform.tfstate` (production, default backend config in `versions.tf`).
- Staging uses a separate state key `serverless/staging/terraform.tfstate` in the SAME `.tf` directory, selected at init time with `terraform init -reconfigure -backend-config="key=serverless/staging/terraform.tfstate"`.
- All other stacks referenced via remote state follow the same bucket/region pattern (see `data.networking.tf`, `data.server.tf`): `key = "<stack>/terraform.tfstate"`.

**production_enabled toggle (ADR-0012, implemented 2026-08-10):**
Every production resource in this stack is gated by `count = var.production_enabled ? 1 : 0` (`envs/production.tfvars` sets `true`, `envs/staging.tfvars` sets `false`). This is what makes the separate state keys viable — applying `staging.tfvars` alone no longer tries to recreate all of production in an empty state.

**Why:** ADR-0012 explicitly required separate state keys per environment for this stack, but the original code had all production resources unconditional — a staging-only apply against a fresh state key would have tried to recreate all of production and collided with real AWS objects. The user explicitly chose the full symmetric-`count` refactor over the additive same-state workaround (dual `-var-file` apply), after understanding the trade-off.

**Cross-state shared resources pattern:** A handful of resources are genuinely shared between production and staging at the network layer and are referenced directly by the `*.staging` resources (staging reuses prod's SGs/subnet-groups rather than duplicating them, per ADR-0012): `aws_security_group.postgresql`, `aws_security_group.documentdb`, `aws_db_subnet_group.this`, `aws_docdb_subnet_group.this`, and `aws_docdb_cluster_parameter_group.this` (this fifth one was NOT listed in the original ADR-0012 task description — discovered during implementation by grepping for direct references inside the `*.staging` resource blocks; always re-verify the shared-resource list this way rather than trusting a hand-written list). These 5 resources are gated by `production_enabled` like everything else (they're "owned" by the production state), but the `*.staging` resources need their IDs/names even when applied against the staging-only state. Solution, in `data.serverless-production.tf`: a `data "terraform_remote_state" "serverless_production"` with `count = var.production_enabled ? 0 : 1` reads the production state's outputs, and locals resolve to either the local `[0]` resource (when `production_enabled=true`) or the remote state output (when `false`). `outputs.tf` exports all 5 as `try(..., null)`.

**How to apply:** When implementing any future ADR that touches this stack's resource conditionality, (1) grep `^resource` for the full list before starting, don't trust a pre-written list from the ADR/task — it may be incomplete; (2) grep every `*.staging`-suffixed resource block for direct (non-suffixed, non-var.staging) references to production resources — those are the ones needing the cross-state local pattern, not a plain `[0]` index; (3) after gating, run `terraform validate` and treat every reference error as a checklist item, not just the ones anticipated up front.
