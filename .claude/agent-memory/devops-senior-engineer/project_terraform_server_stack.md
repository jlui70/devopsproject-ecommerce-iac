---
name: project-terraform-server-stack
description: Terraform server stack (ADR-0002) — outputs, key outputs consumed by Ansible, and implementation notes
metadata:
  type: project
---

The `terraform/server/` stack was implemented as part of ADR-0002 (2026-06-27). It provisions: 2x ASG (control-plane t3.medium 2/2/2, worker t3.micro 4/4/5), NLB internal TCP 6443, IAM roles, ACM certificate, 6 ECR repos, SQS NTH queue, SSM patch association.

**Key outputs consumed by downstream:**
- `nlb_dns_name` — used by Ansible as `controlPlaneEndpoint` in kubeadm config
- `node_termination_queue_url` — used by Ansible NTH Helm install
- `acm_certificate_arn` — consumed by PRD-004, PRD-006
- `control_plane_security_group_id`, `worker_security_group_id` — consumed by PRD-003
- `ecr_repository_urls` — consumed by PRD-004, PRD-005

**Why:** state key is `server/terraform.tfstate` in bucket `devopsproject-terraform-state-files`.

**How to apply:** Ansible `terraform-output.yml` reads this state directly from S3 — no terraform CLI needed on nodes.

See `docs/implementation/IMPL-ADR-0002-2026-06-27.md` for full Terraform implementation log.

[[project-ansible-layer]]
