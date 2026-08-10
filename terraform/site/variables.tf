variable "region" {
  description = "Regiao AWS onde a stack e provisionada"
  type        = string
  nullable    = false
}

variable "assume_role" {
  description = "Configuracao de assume role do Terraform"
  type = object({
    role_arn    = string
    external_id = string
  })
  nullable = false
}

variable "site" {
  description = "Configuracoes do site e buckets S3 associados"
  type = object({
    domain                       = string
    bucket_name                  = string
    logs_bucket_name             = string
    staging_bucket_name          = string
    staging_logs_bucket_name     = string
    alb_name                     = string
    continuous_deployment_header = string
    continuous_deployment_value  = string
    # Emenda ADR-0011 (2026-08-10): frontend estatico do ambiente de aplicacao staging.
    # Nao confundir com staging_bucket_name/staging_logs_bucket_name acima, que sao do
    # CloudFront Continuous Deployment (canario de config de CDN, ADR-0006/0011).
    frontend_staging_domain      = string
    frontend_staging_bucket_name = string
  })
  nullable = false
}

variable "github" {
  description = "Configuracoes do repositorio GitHub para OIDC e IAM roles de CI/CD"
  type = object({
    repo = string
  })
  nullable = false
}
