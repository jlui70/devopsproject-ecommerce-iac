output "github_oidc_provider_arn" {
  description = "ARN do provider OIDC do GitHub Actions — consumido pela stack `site` (roles de frontend)"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_staging_role_arn" {
  description = "ARN da role assumida pelos jobs de build/push/smoke test de staging (secret STAGING_ROLE_ARN)"
  value       = aws_iam_role.github_staging.arn
}

output "github_prod_role_arn" {
  description = "ARN da role assumida pelo job de promocao para producao (secret PROD_ROLE_ARN)"
  value       = aws_iam_role.github_prod.arn
}

output "github_backend_role_arn" {
  description = "ARN da role legada de backend (DEPRECADA — nenhum workflow a utiliza)"
  value       = aws_iam_role.github_backend.arn
}
