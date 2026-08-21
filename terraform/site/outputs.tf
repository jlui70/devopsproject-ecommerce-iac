# ADR-0006: CloudFront + S3 outputs
output "cloudfront_distribution_id" {
  description = "ID da distribuicao CloudFront de producao"
  value       = aws_cloudfront_distribution.production.id
}

output "cloudfront_distribution_domain" {
  description = "Domain name da distribuicao CloudFront de producao"
  value       = aws_cloudfront_distribution.production.domain_name
}

output "cloudfront_staging_distribution_id" {
  description = "ID da distribuicao CloudFront de staging"
  value       = aws_cloudfront_distribution.staging.id
}

output "site_bucket_name" {
  description = "Nome do bucket S3 do site de producao"
  value       = aws_s3_bucket.site.bucket
}

output "staging_bucket_name" {
  description = "Nome do bucket S3 do site de staging"
  value       = aws_s3_bucket.staging.bucket
}

# ADR-0005 / ADR-0023: as roles de ECR (backend/staging/prod) e o provider OIDC
# migraram para a stack `cicd`. Aqui ficam apenas as roles de frontend, que escopam
# permissoes sobre os buckets e distribuicoes desta stack.
output "github_frontend_role_arn" {
  description = "ARN da IAM role para GitHub Actions — deploy de assets S3 e invalidacao CloudFront (frontend de producao)"
  value       = aws_iam_role.github_frontend.arn
}

# ADR-0014: GitHub Actions OIDC IAM roles por ambiente (gate staging->prod)

# Emenda ADR-0011 (2026-08-10): frontend estatico do ambiente de aplicacao staging
output "frontend_staging_role_arn" {
  description = "ARN da IAM role para GitHub Actions — deploy de assets S3 e invalidacao CloudFront do frontend de staging (ref develop/feature/*)"
  value       = aws_iam_role.github_frontend_staging.arn
}

output "frontend_staging_cloudfront_distribution_id" {
  description = "ID da distribuicao CloudFront dedicada ao frontend estatico de staging (app-staging.ecommerce-devopsproject.com)"
  value       = aws_cloudfront_distribution.frontend_staging.id
}

output "frontend_staging_bucket_name" {
  description = "Nome do bucket S3 do frontend estatico de staging"
  value       = aws_s3_bucket.frontend_staging.bucket
}
