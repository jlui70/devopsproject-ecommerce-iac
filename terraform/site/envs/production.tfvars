region = "us-east-1"

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

site = {
  domain                       = "ecommerce-devopsproject.com"
  bucket_name                  = "ecommerce-devopsproject.com"
  logs_bucket_name             = "ecommerce-devopsproject.com-logs"
  staging_bucket_name          = "ecommerce-devopsproject.com-staging"
  staging_logs_bucket_name     = "ecommerce-devopsproject.com-staging-logs"
  alb_name                     = "dpe-ingress-prod"
  continuous_deployment_header = "aws-cf-cd-dpe-bg-beta-tester"
  continuous_deployment_value  = "1"
  # Emenda ADR-0011 (2026-08-10) — frontend estatico do ambiente staging
  frontend_staging_domain      = "app-staging.ecommerce-devopsproject.com"
  frontend_staging_bucket_name = "app-staging.ecommerce-devopsproject.com"
}

github = {
  repo = "jlui70/devopsproject-ecommerce"
}
