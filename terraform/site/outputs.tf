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

# ADR-0005: GitHub Actions OIDC IAM roles
output "github_backend_role_arn" {
  description = "ARN da IAM role para GitHub Actions — push de imagens ECR (backend)"
  value       = aws_iam_role.github_backend.arn
}

output "github_frontend_role_arn" {
  description = "ARN da IAM role para GitHub Actions — deploy de assets S3 e invalidacao CloudFront (frontend)"
  value       = aws_iam_role.github_frontend.arn
}
