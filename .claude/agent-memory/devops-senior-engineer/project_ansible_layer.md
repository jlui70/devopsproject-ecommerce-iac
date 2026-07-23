---
name: project-ansible-layer
description: Ansible bootstrap layer for the Kubernetes cluster (ADR-0002) — structure, key decisions, and prerequisites
metadata:
  type: project
---

Ansible layer created at `devopsproject-ecommerce-iac/ansible/` as part of ADR-0002 implementation (2026-06-27). 37 files across 15 roles plus inventory, config, and site.yml.

**Why:** kubeadm bootstrap is order-dependent across multiple nodes; Ansible via SSM is the chosen approach (no SSH, no port 22). The `server` Terraform stack must be applied first — Ansible reads `nlb_dns_name` and `node_termination_queue_url` directly from `s3://devopsproject-terraform-state-files/server/terraform.tfstate`.

**How to apply:**
- SSM Agent must be present on Debian 12 AMI — it is NOT included by default; must be in Launch Template user_data or custom AMI.
- Bucket `devopsproject-ecommerce-ansible-ssm` is an external prerequisite (not created by any Terraform stack in this repo).
- Control-plane IAM role needs `s3:GetObject` on the state file key for `terraform-output.yml` to succeed.
- Collections required on controller: `community.general`, `community.aws`, `amazon.aws`.
- Cluster Autoscaler image is `v1.30.0` (ADR explicitly mandated alignment away from the v1.26.2 shown in slides).
- `hostnames` role exists but is NOT in `site.yml` — the ADR execution order spec does not list it; adding it requires human decision on placement.

See `docs/implementation/IMPL-ADR-0002-ansible-2026-06-27.md` for full details.

[[project-terraform-server-stack]]
