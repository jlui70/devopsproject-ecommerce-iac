---
name: project-adr0007-observability
description: ADR-0007 Observabilidade Centralizada — stack Terraform observability/ + roles Ansible fluent-bit e metricbeat implementadas
metadata:
  type: project
---

ADR-0007 (Observabilidade Centralizada) foi implementado em 2026-06-27.

Stack path: `devopsproject-ecommerce-iac/terraform/observability/`
Ansible roles: `devopsproject-ecommerce-iac/ansible/roles/fluent-bit/` e `ansible/roles/metricbeat/`

**Why:** Centralizar logs (Fluent Bit) e métricas (Metricbeat) do cluster K8s em OpenSearch na AWS para observabilidade operacional.

**How to apply:** Antes do deploy Ansible, a stack Terraform `observability/` deve estar aplicada e o estado em S3. As roles Ansible leem o state file via `aws s3 cp` e extraem `opensearch_domain_endpoint` e `fluentbit_index_name`. A variável sensível `opensearch_master_password` é injetada via `TF_VAR_opensearch_master_password` — nunca commitada.

Exceção documentada no ADR: provider `opensearch-project/opensearch ~> 2.3` usado APENAS para `opensearch_roles_mapping`. Versão instalada: 2.3.2. Provider AWS instalado: 5.100.0.

`log_publishing_options.cloudwatch_log_group_arn` usa sufixo `:*` conforme exigido pela API AWS para AUDIT_LOGS — confirmado na prática e alinhado com o ADR.

[[project-terraform-conventions]]
