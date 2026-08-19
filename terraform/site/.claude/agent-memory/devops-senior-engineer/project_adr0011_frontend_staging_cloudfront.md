---
name: project-adr0011-frontend-staging-cloudfront
description: Emenda ADR-0011 (2026-08-10) — CloudFront/S3/Route53/IAM dedicados ao frontend estático de staging, implementados em terraform/site
metadata:
  type: project
---

Emenda ao ADR-0011 (2026-08-10, seção "Emenda (2026-08-10)" em
`docs/ADR-0011-estrategia-multi-ambiente-staging.md`) implementada no mesmo dia, em código
apenas — **sem `terraform init`/`plan`/`apply`** (conta AWS destruída na época).

Arquivos novos em `devopsproject-ecommerce-iac/terraform/site/`: `s3.frontend-staging.tf`,
`cloudfront.frontend-staging.tf`, `route53.frontend-staging.tf`,
`iam.github-frontend-staging-role.tf`. Editados: `variables.tf` (`site.frontend_staging_domain`
/ `site.frontend_staging_bucket_name`), `outputs.tf` (3 outputs `frontend_staging_*`),
`envs/production.tfvars` (gitignored — `*.tfvars`, não aparece em `git status`, isso é
esperado no stack `site`, não um erro de edição).

**Why:** a pipeline `deploy-frontend.yml` (já reescrita numa rodada anterior, ADR-0014/0020)
esperava um destino S3+CloudFront de staging para o frontend que nunca foi provisionado —
sincronizava para um bucket placeholder que era na verdade o domínio do backend/API
(`staging.ecommerce-devopsproject.com`). A decisão original do ADR-0011 ("staging sem
CloudFront/WAF dedicado") cobria só o backend; a emenda abre uma exceção pontual e estrita só
para o frontend estático.

**How to apply:** ao mexer neste stack de novo —
- domínio novo é `app-staging.ecommerce-devopsproject.com` (frontend, público, CloudFront) —
  **não confundir** com `staging.ecommerce-devopsproject.com` (backend/API interno via ALB,
  ADR-0014, estrutura própria fora do `site` stack) nem com `aws_cloudfront_distribution.staging`
  / `aws_s3_bucket.staging` em `cloudfront.staging.tf`/`s3.staging.tf` (isso é o *CloudFront
  Continuous Deployment*, canário de config de CDN do ADR-0006, recurso pré-existente e
  totalmente não relacionado).
- o stack `site` só tem `envs/production.tfvars` (sem `staging.tfvars`) — o ambiente de
  aplicação `staging` deste ADR não tem tfvars próprio neste stack específico, os valores
  `-stg`/`frontend_staging_*` ficam dentro do mesmo `production.tfvars`.
- o projeto reusa 1 único `aws_cloudfront_origin_access_control` (`cloudfront.oac.tf`) para
  todas as origens S3 do stack — não criar um OAC por distribuição.
- `data.aws_acm_certificate.this` (filtro `domain = var.site.domain`, o apex) já cobre
  subdomínios novos porque o certificado tem SAN wildcard `*.ecommerce-devopsproject.com`
  (ADR-0010) — não precisa de um novo `data` source por subdomínio.
- pendência real após o próximo `apply`: configurar os secrets `FRONTEND_STAGING_ROLE_ARN` e
  `FRONTEND_STAGING_CLOUDFRONT_DISTRIBUTION_ID` no repo GitHub com os outputs
  `frontend_staging_role_arn` / `frontend_staging_cloudfront_distribution_id`.

Validação local feita: `terraform fmt -recursive` + `terraform validate` → `Success`. Detalhe
completo em `docs/implementation/IMPL-ADR-0011-0012-0013-0014-0020-2026-08-10.md`, subseção
"Emenda ADR-0011 — frontend staging CloudFront".

[[project-adr0007-observability]]
